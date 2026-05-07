from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Hydrus Backend API"
    app_env: str = "development"

    db_host: str = "db"
    db_port: int = 5432
    db_name: str = "hydrus"
    db_user: str = "hydrus"
    db_password: str = "hydrus_pass"

    cors_origins: str = "*"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()
