package continuityaudit

import (
	"errors"
	"strings"
)

type EventKind string

const (
	CommitmentRegistered EventKind = "commitment_registered"
	AttributionEdgeAdded EventKind = "attribution_edge_added"
	ForkDeclared         EventKind = "fork_declared"
	MigrationDeclared    EventKind = "migration_declared"
	PolicyUpdated        EventKind = "policy_updated"
	CorrectionLinked     EventKind = "correction_linked"
	WitnessAdded         EventKind = "witness_added"
	ModelUpdateRecorded  EventKind = "model_update_recorded"
	SunsetRecorded       EventKind = "sunset_recorded"
)

type Witness struct {
	WitnessReference    string
	CosignatureReference string
	WitnessedAtRFC3339  string
}

type MerkleAuditEntry struct {
	Sequence                        uint64
	EventID                         string
	EventKind                       EventKind
	PreviousEntryReference          string
	EventContentReference           string
	MerkleRootReference             string
	PolicyBundleReference           string
	Witnesses                       []Witness
	RecordedAtRFC3339               string
	IdentityCertificationClaimed    bool
	ContinuityCertificationClaimed  bool
	HostMigrationCertificationClaimed bool
}

func (entry MerkleAuditEntry) ValidateAgainstPrevious(previous *MerkleAuditEntry) error {
	if err := requireText("event id", entry.EventID); err != nil {
		return err
	}

	if err := requireText("event content reference", entry.EventContentReference); err != nil {
		return err
	}

	if err := requireText("merkle root reference", entry.MerkleRootReference); err != nil {
		return err
	}

	if err := requireText("policy bundle reference", entry.PolicyBundleReference); err != nil {
		return err
	}

	if err := requireText("recorded at", entry.RecordedAtRFC3339); err != nil {
		return err
	}

	if len(entry.Witnesses) == 0 {
		return errors.New("at least one witness is required")
	}

	seenWitnesses := make(map[string]struct{}, len(entry.Witnesses))
	for _, witness := range entry.Witnesses {
		if err := requireText("witness reference", witness.WitnessReference); err != nil {
			return err
		}

		if err := requireText("cosignature reference", witness.CosignatureReference); err != nil {
			return err
		}

		if _, exists := seenWitnesses[witness.WitnessReference]; exists {
			return errors.New("duplicate witness reference")
		}

		seenWitnesses[witness.WitnessReference] = struct{}{}
	}

	if entry.IdentityCertificationClaimed ||
		entry.ContinuityCertificationClaimed ||
		entry.HostMigrationCertificationClaimed {
		return errors.New("certification claims are prohibited")
	}

	if previous == nil {
		if entry.Sequence != 0 || entry.PreviousEntryReference != "" {
			return errors.New("invalid genesis entry")
		}

		return nil
	}

	if entry.Sequence != previous.Sequence+1 {
		return errors.New("non-sequential append-only entry")
	}

	if entry.PreviousEntryReference != previous.EventID {
		return errors.New("previous entry reference does not match")
	}

	return nil
}

func requireText(field string, value string) error {
	if strings.TrimSpace(value) == "" {
		return errors.New(field + " must not be empty")
	}

	return nil
}
