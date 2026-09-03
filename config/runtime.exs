import Config

if config_env() in [:dev, :prod] do
  openrouter_api_key = System.get_env("OPENROUTER_API_KEY")
  telegram_bot_token  = System.get_env("TELEGRAM_BOT_TOKEN")
  secret_key_base  = System.get_env("SECRET_KEY_BASE")
  secure_api_key = System.get_env("SECURE_USER_API_MASTER_KEY")

  app_host = System.get_env("APP_HOST", "localhost")

  db_password = System.get_env("DB_PASSWORD")
  db_hostname = System.get_env("DB_HOSTNAME")
  db_username = System.get_env("DB_USERNAME")
  db_port = System.get_env("DB_PORT")
  db_poolsize = System.get_env("DB_POOLSIZE")

  # Задаем конфиг для AI-провайдера(ов)
  config :messenger, :ai_providers,
         openrouter_api_key: openrouter_api_key

  # Задаем telegram bot token
  config :messenger, :telegram,
         bot_token: telegram_bot_token

  # Конфиг для Cloak Vault (мастер-ключ шифрования апи ключей у пользователей)
  binary_key = case Base.decode16(secure_api_key, case: :mixed) do
    {:ok, bytes} -> bytes
    _ -> secure_api_key
  end

  config :messenger, Messenger.Vault,
         ciphers: [
           default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: binary_key}
         ]

  # Точка входа в приложение (Phoenix Endpoint)
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :messenger, MessengerWeb.Endpoint,
         url: [
           host: app_host,
           port: if(config_env() == :prod, do: 443, else: port),
           scheme: if(config_env() == :prod, do: "https", else: "http")
         ],
         http: [
           ip: {0, 0, 0, 0, 0, 0, 0, 0},
           port: port
         ],
         secret_key_base: secret_key_base,
         server: System.get_env("PHX_SERVER") || config_env() == :dev

  # Задаем конфиг для базы данных
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :messenger, Messenger.Repo,
    ssl: false,
    show_sensitive_data_on_connection_error: true,
    username: db_username,
    password: db_password,
    hostname: db_hostname,
    port: db_port,
    pool_size: String.to_integer(db_poolsize),
    socket_options: maybe_ipv6


  secret_key_base = System.get_env("SECRET_KEY_BASE")

  host = System.get_env("PHX_HOST") || "example.com"

  config :messenger, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :messenger, MessengerWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :messenger, MessengerWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
end
