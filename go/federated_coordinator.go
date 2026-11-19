package federated

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"sync"
)

type RoundConfig struct {
	MinimumCohortSize int
	MaximumEpsilon    float64
	ExpectedModel     string
}

type ProtectedUpdate struct {
	CohortPseudonym            string
	ModelVersion               string
	MaskedUpdate               []float64
	PrivacyEpsilonUsed         float64
	ProtocolCompliant          bool
	AccessibilityParityEvidence bool
}

type RoundResult struct {
	Accepted          bool
	Reason            string
	AggregateUpdate   []float64
	CumulativeEpsilon float64
	Commitment        string
}

type Coordinator struct {
	mu     sync.Mutex
	config RoundConfig
}

func NewCoordinator(config RoundConfig) (*Coordinator, error) {
	if config.MinimumCohortSize < 2 {
		return nil, errors.New("minimum cohort size must be at least two")
	}
	if config.MaximumEpsilon <= 0 {
		return nil, errors.New("maximum epsilon must be greater than zero")
	}
	if config.ExpectedModel == "" {
		return nil, errors.New("expected model version is required")
	}
	return &Coordinator{config: config}, nil
}

func (c *Coordinator) Aggregate(updates []ProtectedUpdate) (RoundResult, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	valid := make([]ProtectedUpdate, 0, len(updates))
	for _, update := range updates {
		if !update.ProtocolCompliant ||
			!update.AccessibilityParityEvidence ||
			update.ModelVersion != c.config.ExpectedModel ||
			update.PrivacyEpsilonUsed > c.config.MaximumEpsilon ||
			len(update.MaskedUpdate) == 0 {
			continue
		}
		valid = append(valid, update)
	}

	if len(valid) < c.config.MinimumCohortSize {
		return c.abort("minimum secure-aggregation cohort not met"), nil
	}

	dimension := len(valid[0].MaskedUpdate)
	for _, update := range valid {
		if len(update.MaskedUpdate) != dimension {
			return c.abort("inconsistent protected-update dimensions"), nil
		}
	}

	aggregate := make([]float64, dimension)
	var maxEpsilon float64
	for _, update := range valid {
		maxEpsilon = math.Max(maxEpsilon, update.PrivacyEpsilonUsed)
		for index, value := range update.MaskedUpdate {
			if math.IsNaN(value) || math.IsInf(value, 0) {
				return c.abort("non-finite protected update"), nil
			}
			aggregate[index] += value
		}
	}

	for index := range aggregate {
		aggregate[index] /= float64(len(valid))
	}

	commitmentMaterial := fmt.Sprintf(
		"%s|%d|%.8f|%v",
		c.config.ExpectedModel,
		len(valid),
		maxEpsilon,
		aggregate,
	)
	digest := sha256.Sum256([]byte(commitmentMaterial))

	return RoundResult{
		Accepted:          true,
		Reason:            "aggregate accepted pending validation and human release",
		AggregateUpdate:   aggregate,
		CumulativeEpsilon: maxEpsilon,
		Commitment:        hex.EncodeToString(digest[:]),
	}, nil
}

func (c *Coordinator) abort(reason string) RoundResult {
	digest := sha256.Sum256([]byte("aborted|" + reason))
	return RoundResult{
		Accepted:   false,
		Reason:     reason,
		Commitment: hex.EncodeToString(digest[:]),
	}
}
