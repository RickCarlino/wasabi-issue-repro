# This script demonstrates an issue with Wasabi v5.1.0 (used by Savon ~> 2.15.1)
# where the `:order!` key, representing the element order from an <xsd:sequence>,
# is not populated in the parsed type hash when the element is defined using
# an anonymous complex type directly within the <xsd:element> tag.
# It correctly populates `:order!` for named complex types defined separately.

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  # Use Savon 2.15.1 which depends on Wasabi ~> 5.1.0
  gem 'savon', '~> 2.15.1'
  # To compare with old behavior (where :order! is present but primitives fail later):
  # gem 'savon', '~> 2.11.1' # Or compatible version using Wasabi 3.x
  # gem 'wasabi', '~> 3.8.0'
end

require 'savon'
require 'pathname'

# --- WSDL Setup ---
WSDL_FILE = Pathname.new(__FILE__).dirname.join('minimal.wsdl')
unless WSDL_FILE.exist?
  puts "ERROR: minimal.wsdl not found."
  puts "Please save the minimal WSDL content as 'minimal.wsdl' in the same directory as this script."
  exit 1
end
wsdl_content = WSDL_FILE.read

# --- Version Info ---
puts "Ruby version: #{RUBY_VERSION}"
puts "Savon version: #{Savon::VERSION}"
# Ensure Wasabi is loaded and get its version spec
wasabi_spec = Gem.loaded_specs['wasabi']
if wasabi_spec
  puts "Wasabi version: #{wasabi_spec.version}"
else
  # Savon 2.x might bundle Wasabi differently sometimes, try resolving dependency
  savon_spec = Gem.loaded_specs['savon']
  wasabi_dep = savon_spec&.runtime_dependencies&.find { |dep| dep.name == 'wasabi' }
  puts "Wasabi version: Could not load directly (Dependency spec: #{wasabi_dep&.requirement || 'N/A'})"
end
puts "-------------------------------------"

# --- Test Logic ---
begin
  # Initialize client with local WSDL content
  client = Savon.client(wsdl: wsdl_content, log: false, log_level: :error)

  # Access the parsed WSDL data via Wasabi parser
  parser = client.instance_variable_get(:@wsdl)&.parser
  unless parser
    raise "Failed to get Wasabi parser instance from Savon client."
  end

  types_hash = parser.types
  unless types_hash && types_hash.is_a?(Hash)
    raise "parser.types did not return a Hash. Got: #{types_hash.inspect}"
  end

  target_namespace = "http://example.com/minimalorder"

  puts "\nInspecting parsed types hash for namespace: #{target_namespace}"
  types_in_namespace = types_hash[target_namespace]

  unless types_in_namespace
      raise "ERROR: Namespace URI '#{target_namespace}' not found as a key in parser.types! Available keys: #{types_hash.keys.inspect}"
  end

  puts "Namespace found. Checking specific type/element definitions..."

  # --- 1. Test the Element with Anonymous Complex Type ---
  element_name_anon = "ElementWithAnonymousTypeAndSequence"
  puts "\n[TEST CASE 1: Element with Anonymous Type + Sequence]"
  puts "Checking for definition of element: '#{element_name_anon}'"
  anon_type_def = types_in_namespace[element_name_anon]

  if anon_type_def
    puts " -> Definition Found."
    order_key_present = anon_type_def.key?(:order!)
    order_value = anon_type_def[:order!]
    puts " -> Has :order! key? #{order_key_present}"
    puts " -> Value of :order!: #{order_value.inspect}"
    if order_key_present
        puts " -> UNEXPECTED (based on bug): :order! key is present."
    else
        puts " -> *** EXPECTED ISSUE: :order! key is MISSING. ***"
        puts "    (WSDL sequence was: fieldB, fieldA, fieldC)"
    end
  else
    puts " -> ERROR: Definition NOT found for '#{element_name_anon}'!"
  end

  # --- 2. Test the Named Complex Type (Control Case) ---
  type_name_named = "NamedComplexType"
  puts "\n[TEST CASE 2: Named Complex Type + Sequence (Control)]"
  puts "Checking for definition of type: '#{type_name_named}'"
  named_type_def = types_in_namespace[type_name_named]

  if named_type_def
    puts " -> Definition Found."
    order_key_present = named_type_def.key?(:order!)
    order_value = named_type_def[:order!]
    expected_order = ["fieldY", "fieldX"]
    puts " -> Has :order! key? #{order_key_present}"
    puts " -> Value of :order!: #{order_value.inspect}"
    if order_key_present && order_value == expected_order
      puts " -> CORRECT: :order! key is present with expected value."
    elsif order_key_present
      puts " -> UNEXPECTED: :order! key is present BUT value is wrong. Expected: #{expected_order.inspect}"
    else
      puts " -> UNEXPECTED: :order! key is MISSING but should be present for named type."
    end
  else
    puts " -> ERROR: Definition NOT found for '#{type_name_named}'!"
  end

  # --- 3. Test the Element referencing the Named Type (Informational) ---
  element_name_named_ref = "ElementWithNamedType"
  puts "\n[TEST CASE 3: Element referencing Named Type (Info)]"
  puts "Checking for definition of element: '#{element_name_named_ref}'"
  named_element_def = types_in_namespace[element_name_named_ref]
  if named_element_def
      puts " -> Definition Found."
      # Elements referencing types don't usually have :order! themselves.
      puts " -> Type referenced: #{named_element_def[:type]}"
      puts " -> Has :order! key? #{named_element_def.key?(:order!)}"
  else
      puts " -> ERROR: Definition NOT found for '#{element_name_named_ref}'!"
  end

rescue => e
  puts "\n--- SCRIPT FAILED ---"
  puts e.message
  puts "Backtrace:"
  puts e.backtrace.join("\n  ")
  exit 1
end

puts "\n-------------------------------------"
puts "Script finished."