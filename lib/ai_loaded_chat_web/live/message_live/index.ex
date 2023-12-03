defmodule AiLoadedChatWeb.MessageLive.New do
  use AiLoadedChatWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       pid: self(),
       input: nil,
       history: [],
       user_image: nil,
       bot_image: nil,
       image_gen_in_progress: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1>AI Chat</h1>
      <div
        class="messages"
        style="border: 1px solid #eee; height: 400px; overflow: scroll; margin-bottom: 8px;"
      >
        <%= for {sender, message} <- Enum.reverse(@history) do %>
          <div class="flex">
            <%= if sender == :generated do %>
              <img src={"data:image/png;base64,#{@bot_image}"} alt="bot image" width="50" height="50" />
            <% else %>
              <img
                src={"data:image/png;base64,#{@user_image}"}
                alt="user image"
                width="50"
                height="50"
              />
            <% end %>
            <%= "#{sender}: #{message}" %>
          </div>
        <% end %>
      </div>
      <form phx-change="set">
        <input type="text" name="text" value={@input} />
      </form>
      <.button phx-click="enhance">Enhance</.button>
      <.button phx-click="send">Send</.button>
      <.button phx-click="reset">Reset</.button>
      <.button phx-click="generate_user_image" disabled={@image_gen_in_progress}>
        Generate user image
      </.button>
      <.button phx-click="generate_bot_image" disabled={@image_gen_in_progress}>
        Generate bot image
      </.button>
    </div>
    """
  end

  @impl true
  def handle_event("set", %{"text" => message}, socket) do
    {:noreply, assign(socket, input: message)}
  end

  def handle_event("reset", _, socket) do
    {:noreply, assign(socket, history: [])}
  end

  def handle_event("enhance", _, %{assigns: %{input: input}} = socket) do
    %{results: [%{text: text}]} =
      Nx.Serving.batched_run(TextGenerationServing, input)

    {:noreply, assign(socket, input: text)}
  end

  def handle_event("send", _, %{assigns: %{history: history, input: input}} = socket) do
    %{history: history} =
      Nx.Serving.batched_run(ConversationServing, %{
        text: input,
        history: history
      })

    {:noreply, assign(socket, input: "", history: history)}
  end

  def handle_event("generate_user_image", _, %{assigns: %{pid: pid, input: input}} = socket) do
    Task.start(fn ->
      res = Nx.Serving.batched_run(ImageServing, input)
      [image] = res.results

      image =
        image.image
        |> StbImage.from_nx()
        |> StbImage.resize(100, 100)
        |> StbImage.to_binary(:png)
        |> Base.encode64()

      Process.send(pid, {:user_image, image}, [])
    end)

    {:noreply, assign(socket, input: "", image_gen_in_progress: true)}
  end

  def handle_event("generate_bot_image", _, %{assigns: %{pid: pid, input: input}} = socket) do
    Task.start(fn ->
      res = Nx.Serving.batched_run(ImageServing, input)
      [image] = res.results

      image =
        image.image
        |> StbImage.from_nx()
        |> StbImage.resize(100, 100)
        |> StbImage.to_binary(:png)
        |> Base.encode64()

      Process.send(pid, {:bot_image, image}, [])
    end)

    {:noreply, assign(socket, input: "", image_gen_in_progress: true)}
  end

  @impl true
  def handle_info({:user_image, image}, socket) do
    {:noreply, assign(socket, user_image: image, image_gen_in_progress: false)}
  end

  def handle_info({:bot_image, image}, socket) do
    {:noreply, assign(socket, bot_image: image, image_gen_in_progress: false)}
  end
end
