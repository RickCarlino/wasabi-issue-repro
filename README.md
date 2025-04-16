# Savon/Wasabi Issue Reproduction

## Wasabi v5.1.0 Fails to Parse :order! for Anonymous Complex Type Sequences

This repository demonstrates a bug in Wasabi v5.1.0 (used by Savon ~> 2.15.1) where the `:order!` key is not correctly populated for XML elements with anonymous complex types that contain sequence definitions.

**Bug details:**
- The `:order!` key, which represents the element ordering from an `<xsd:sequence>`, is not included in the parsed type hash when an element is defined using an anonymous complex type.
- This issue affects proper serialization of SOAP messages where element order matters.
- The bug only happens with anonymous complex types. Named complex types correctly maintain their `:order!` values.

## Reproduction Steps

1. Clone this repository
2. Run the reproduction script:
   ```
   ruby repro.rb
   ```

## Expected vs. Actual Behavior

**Expected behavior:**
- Both anonymous complex types and named complex types should include an `:order!` key in their parsed type definitions that preserves the element ordering from the XSD sequence.

**Actual behavior:**
- Named complex types correctly include the `:order!` key with the proper element sequence.
- Anonymous complex types (defined directly within an element) are missing the `:order!` key entirely.

## Technical Details

The repository contains:

1. **minimal.wsdl** - A minimal WSDL file demonstrating the issue with:
   - `ElementWithAnonymousTypeAndSequence` - Uses an anonymous complex type with a sequence (MISSING `:order!`)
   - `NamedComplexType` - A separately defined complex type with a sequence (correctly has `:order!`)
   - `ElementWithNamedType` - An element that references the named type

2. **repro.rb** - A Ruby script that:
   - Uses Bundler inline to ensure the correct Savon and Wasabi versions
   - Loads the WSDL and analyzes the parsed type definitions
   - Demonstrates that `:order!` is missing for the anonymous complex type

## Environment Information

- Savon version: ~> 2.15.1
- Wasabi version: ~> 5.1.0
- Ruby version: [Filled in when script is run]

## Related Notes

- This issue affects applications that rely on maintaining element order in SOAP requests with complex types.
- Prior versions of Wasabi (3.x) included `:order!` keys for anonymous types, but had other serialization issues.

## Additional Context

The issue appears to be in Wasabi's WSDL parser, specifically in how it processes anonymous complex types with sequence definitions. While it correctly identifies and processes the elements, it fails to generate the `:order!` key that Savon needs for proper serialization.