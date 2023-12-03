defmodule AiLoadedChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AiLoadedChatWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ai_loaded_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AiLoadedChat.PubSub},
      {Nx.Serving, serving: conversation_serving_setup(), name: ConversationServing},
      {Nx.Serving, serving: text_generation_serving_setup(), name: TextGenerationServing},
      {Nx.Serving, serving: image_serving_setup(), name: ImageServing},
      AiLoadedChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AiLoadedChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AiLoadedChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Nx.Serving.batched_run(ConversationServing, %{text: message, history: history})

  defp conversation_serving_setup do
    repository_id = "facebook/blenderbot-400M-distill"

    {:ok, model_info} = Bumblebee.load_model({:hf, repository_id})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repository_id})

    {:ok, generation_config} =
      Bumblebee.load_generation_config({:hf, repository_id})

    Bumblebee.Text.conversation(
      model_info,
      tokenizer,
      generation_config,
      compile: [batch_size: 4, sequence_length: 500],
      defn_options: [compiler: EXLA]
    )
  end

  # Nx.Serving.batched_run(TextGenerationServing, message)

  defp text_generation_serving_setup do
    repository_id = "gpt2"

    {:ok, model_info} = Bumblebee.load_model({:hf, repository_id})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, repository_id})

    {:ok, generation_config} =
      Bumblebee.load_generation_config({:hf, repository_id})

    generation_config = Bumblebee.configure(generation_config, max_new_tokens: 15)

    Bumblebee.Text.generation(
      model_info,
      tokenizer,
      generation_config,
      compile: [batch_size: 4, sequence_length: 50],
      defn_options: [compiler: EXLA]
    )
  end

  # res = Nx.Serving.batched_run(ImageServing, "yellow car")
  # [image] = res.results
  # image = StbImage.from_nx(image.image)
  # StbImage.write_file image, "test.png"
  # :filename.basedir(:user_cache, "bumblebee")
  defp image_serving_setup do
    repository_id = "CompVis/stable-diffusion-v1-4"

    {:ok, image_tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/clip-vit-large-patch14"})

    {:ok, clip} = Bumblebee.load_model({:hf, repository_id, subdir: "text_encoder"})

    {:ok, unet} =
      Bumblebee.load_model({:hf, repository_id, subdir: "unet"},
        params_filename: "diffusion_pytorch_model.bin"
      )

    {:ok, vae} =
      Bumblebee.load_model({:hf, repository_id, subdir: "vae"},
        architecture: :decoder,
        params_filename: "diffusion_pytorch_model.bin"
      )

    {:ok, scheduler} = Bumblebee.load_scheduler({:hf, repository_id, subdir: "scheduler"})

    Bumblebee.Diffusion.StableDiffusion.text_to_image(
      clip,
      unet,
      vae,
      image_tokenizer,
      scheduler,
      num_steps: 5,
      num_images_per_prompt: 1,
      compile: [batch_size: 1, sequence_length: 10],
      defn_options: [compiler: EXLA]
    )
  end
end
