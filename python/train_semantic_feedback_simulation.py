from ray.rllib.algorithms.ppo import PPOConfig
from ray.tune.registry import register_env

from semantic_feedback_multi_agent_env import SemanticFeedbackMultiAgentEnv


def policy_mapping_fn(agent_id: str, *args, **kwargs) -> str:
    return "shared_semantic_policy"


register_env(
    "semantic_feedback_multi_agent_env",
    lambda config: SemanticFeedbackMultiAgentEnv(config),
)

config = (
    PPOConfig()
    .environment(
        env="semantic_feedback_multi_agent_env",
        env_config={
            "agent_count": 3,
            "maximum_steps": 24,
            "synthetic_budget": 1.0,
            "host_consent_active": True,
            "advisory_only": True,
            "human_review_required": True,
            "privacy_minimization_required": True,
            "accessibility_equivalence_required": True,
        },
    )
    .multi_agent(
        policies={"shared_semantic_policy"},
        policy_mapping_fn=policy_mapping_fn,
    )
)

algorithm = config.build()
result = algorithm.train()
print(result["episode_return_mean"])
