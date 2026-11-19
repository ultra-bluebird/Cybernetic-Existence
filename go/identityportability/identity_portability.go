package identityportability

import (
	"errors"
	"strings"
)

type Protocol string

const (
	ProtocolDID         Protocol = "did"
	ProtocolATProtocol  Protocol = "at_protocol"
	ProtocolNostr       Protocol = "nostr"
	ProtocolActivityPub Protocol = "activitypub"
	ProtocolDIDComm     Protocol = "didcomm"
	ProtocolFuture      Protocol = "future_protocol"
)

type ProtocolBinding struct {
	Protocol               Protocol
	SubjectReference       string
	PublicKeyOrDIDReference string
	ProvenanceReference    string
	PortabilityScope       string
	ConsentScopeReference  string
}

type Functor struct {
	PortableSubjectReference      string
	SourceBinding                 ProtocolBinding
	TargetBinding                 ProtocolBinding
	MappingReference              string
	PolicyBundleReference         string
	IdentityVerificationClaimed   bool
	IdentityAdjudicationPermitted bool
}

func (f Functor) Validate() error {
	if err := requireText("portable subject reference", f.PortableSubjectReference); err != nil {
		return err
	}

	if err := validateBinding(f.SourceBinding); err != nil {
		return err
	}

	if err := validateBinding(f.TargetBinding); err != nil {
		return err
	}

	if err := requireText("mapping reference", f.MappingReference); err != nil {
		return err
	}

	if err := requireText("policy bundle reference", f.PolicyBundleReference); err != nil {
		return err
	}

	if f.IdentityVerificationClaimed || f.IdentityAdjudicationPermitted {
		return errors.New("identity verification and adjudication are prohibited")
	}

	if f.SourceBinding.Protocol == f.TargetBinding.Protocol &&
		f.SourceBinding.SubjectReference == f.TargetBinding.SubjectReference {
		return errors.New("source and target bindings must differ")
	}

	return nil
}

func validateBinding(binding ProtocolBinding) error {
	if err := requireText("subject reference", binding.SubjectReference); err != nil {
		return err
	}

	if err := requireText("public key or DID reference", binding.PublicKeyOrDIDReference); err != nil {
		return err
	}

	if err := requireText("provenance reference", binding.ProvenanceReference); err != nil {
		return err
	}

	if err := requireText("portability scope", binding.PortabilityScope); err != nil {
		return err
	}

	return requireText("consent scope reference", binding.ConsentScopeReference)
}

func requireText(field string, value string) error {
	if strings.TrimSpace(value) == "" {
		return errors.New(field + " must not be empty")
	}

	return nil
}
