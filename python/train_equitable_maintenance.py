from __future__ import annotations

from pathlib import Path

from sb3_contrib import MaskablePPO
from stable_baselines3.common.monitor import Monitor

from equitable_maintenance_env import EquitableMaintenanceEnv, MaintenanceTask


def build_training_environment() -> EquitableMaintenanceEnv:
    tasks = [
        MaintenanceTask(0, 0, 0.80, 0.95, 0.25, True, 12.0, 450.0, True, True),
        MaintenanceTask(0, 1, 0.50, 0.55, 0.16, False, 10.0, 360.0, True, True),
        MaintenanceTask(1, 2, 0.90, 0.98, 0.30, True, 28.0, 620.0, True, True),
        MaintenanceTask(1, 3, 0.45, 0.45, 0.12, False, 20.0, 300.0, True, True),
        MaintenanceTask(2, 4, 0.75, 0.90, 0.22, True, 42.0, 800.0, True, True),
        MaintenanceTask(2, 5, 0.40, 0.35, 0.10, False, 30.0, 420.0, True, True),
    ]
    return EquitableMaintenanceEnv(tasks=tasks, district_count=3)


def main() -> None:
    environment = Monitor(build_training_environment())
    model = MaskablePPO(
        policy="MlpPolicy",
        env=environment,
        verbose=1,
        learning_rate=3e-4,
        n_steps=256,
        batch_size=64,
        gamma=0.98,
        seed=42,
    )
    model.learn(total_timesteps=100_000)
    output_path = Path("models")
    output_path.mkdir(parents=True, exist_ok=True)
    model.save(output_path / "equitable_maintenance_maskable_ppo")


if __name__ == "__main__":
    main()
