// File: crates/bioscale-evidence-macros/src/lib.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]

use proc_macro::TokenStream;
use quote::{format_ident, quote};
use serde::Deserialize;
use std::fs;
use std::path::PathBuf;
use syn::{parse_macro_input, AttributeArgs, DeriveInput, Lit, Meta, NestedMeta};

/// Attribute macro:
/// #[CorridorEvidence(path = "data/evidence/my_struct.yaml", registry = "evidence::REGISTRY")]
/// Applied to a struct, it:
/// - Reads the YAML evidence file at build time.
/// - Deserialises a fixed-size array of 10 evidence tags.
/// - Verifies short-hex identifiers are valid 0x-prefixed 48-bit values.
/// - Generates a `const EVIDENCE_BUNDLE_<STRUCT_NAME>: EvidenceBundle`.
/// - Injects a `pub const EVIDENCE_BUNDLE: EvidenceBundle` associated const into the impl block.
///
/// YAML layout:
/// ```yaml
/// registry_ref: "evidence.corridor.my_struct.v1"
/// tags:
///   - shorthex: "0xa1b2c3d4e5f6"
///     description: "Some domain anchor."
///   - ...
/// ```
/// Exactly 10 tags must be provided.
#[proc_macro_attribute]
pub fn CorridorEvidence(args: TokenStream, input: TokenStream) -> TokenStream {
    let args = parse_macro_input!(args as AttributeArgs);
    let ast = parse_macro_input!(input as DeriveInput);

    let mut yaml_path: Option<String> = None;
    let mut _registry: Option<String> = None;

    for arg in args {
        match arg {
            NestedMeta::Meta(Meta::NameValue(nv)) if nv.path.is_ident("path") => {
                if let Lit::Str(s) = nv.lit {
                    yaml_path = Some(s.value());
                }
            }
            NestedMeta::Meta(Meta::NameValue(nv)) if nv.path.is_ident("registry") => {
                if let Lit::Str(s) = nv.lit {
                    _registry = Some(s.value());
                }
            }
            _ => {}
        }
    }

    let yaml_path = yaml_path.expect("CorridorEvidence requires `path = \"...\"`");

    #[derive(Debug, Deserialize)]
    struct YamlTag {
        shorthex: String,
        description: String,
    }

    #[derive(Debug, Deserialize)]
    struct YamlEvidence {
        registry_ref: String,
        tags: Vec<YamlTag>,
    }

    let manifest_dir =
        std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set for build");
    let mut path = PathBuf::from(manifest_dir);
    path.push(&yaml_path);

    let yaml_bytes =
        fs::read(&path).unwrap_or_else(|e| panic!("Failed to read YAML evidence file {:?}: {e}", path));
    let yaml: YamlEvidence = serde_yaml::from_slice(&yaml_bytes)
        .unwrap_or_else(|e| panic!("Failed to parse YAML evidence file {:?}: {e}", path));

    if yaml.tags.len() != 10 {
        panic!(
            "CorridorEvidence expected exactly 10 tags, found {} in {:?}",
            yaml.tags.len(),
            path
        );
    }

    let mut tag_shorthex_vals = Vec::with_capacity(10);
    let mut tag_desc_vals = Vec::with_capacity(10);

    for tag in &yaml.tags {
        if !tag.shorthex.starts_with("0x") {
            panic!(
                "shorthex '{}' must start with 0x in evidence file {:?}",
                tag.shorthex, path
            );
        }
        let hex_str = &tag.shorthex[2..];
        if hex_str.len() != 12 {
            panic!(
                "shorthex '{}' must be 48-bit (12 hex chars) in evidence file {:?}",
                tag.shorthex, path
            );
        }
        let parsed = u64::from_str_radix(hex_str, 16).unwrap_or_else(|e| {
            panic!(
                "shorthex '{}' is not valid hex in evidence file {:?}: {e}",
                tag.shorthex, path
            )
        });
        if parsed > 0xFFFF_FFFF_FFFF {
            panic!(
                "shorthex '{}' exceeds 48-bit range in evidence file {:?}",
                tag.shorthex, path
            );
        }
        let full_val: u64 = parsed;
        let full_lit = format!("0x{full_val:012x}");
        tag_shorthex_vals.push(syn::LitInt::new(full_lit.as_str(), proc_macro2::Span::call_site()));
        tag_desc_vals.push(syn::LitStr::new(
            &tag.description,
            proc_macro2::Span::call_site(),
        ));
    }

    let registry_ref_lit =
        syn::LitStr::new(&yaml.registry_ref, proc_macro2::Span::call_site());

    let struct_name = &ast.ident;
    let const_ident = format_ident!("EVIDENCE_BUNDLE_{}", struct_name.to_string().to_uppercase());

    let expanded = quote! {
        #ast

        impl #struct_name {
            pub const EVIDENCE_BUNDLE: crate::EvidenceBundle = crate::EvidenceBundle::new(
                [
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                    crate::EvidenceTag { shorthex: #tag_shorthex_vals, description: #tag_desc_vals },
                ],
                #registry_ref_lit,
            );
        }

        pub const #const_ident: crate::EvidenceBundle = #struct_name::EVIDENCE_BUNDLE;
    };

    expanded.into()
}
