import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ai_loaded_chat, AiLoadedChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "lL8h4K4XzsaU5iVmGL1AB3IoG8shPcuMH/XAoUb2qwlXJYofFfQ0rvA2FYX9/irV",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
