defmodule Cmsbear.Render do

  def get_includes_used(text) do
    Regex.scan(~r/{{\s*include\s+(?<include_name>[a-zA-Z0-9\.]+)\s*}}/, text)
    |> Enum.map(&(&1 |> Enum.at(1)))
  end

  def get_variables_used(text) do
    Regex.scan(~r/{{\s*var\s+(?<var_name>[a-zA-Z0-9]+)\s*}}/, text)
    |> Enum.map(&(&1 |> Enum.at(1) |> String.to_existing_atom()))
  end

  def get_layout(name, layouts) do
    case name do
      "blank" -> "{{content}}"
      _ -> layouts[name]
    end
  end

  def render(text, context, layouts, includes) when is_binary(text) and is_map(context) and is_map(layouts) and is_map(includes) do
    with_includes = Enum.reduce(get_includes_used(text), text, fn include_name, acc ->
      include_text = render(includes[include_name].body, %{layout: "blank"}, %{}, includes)
      String.replace(acc, ~r/{{\s*include\s+#{include_name}\s*}}/, include_text, [:global])
    end)

    with_variables = Enum.reduce(get_variables_used(text), with_includes, fn var_name, acc ->
      String.replace(acc, ~r/{{\s*var\s+#{var_name}\s*}}/, context[var_name], [:global])
    end)

    layout = Map.get(context, :layout, "blank")
    in_layout = String.replace(get_layout(layout, layouts), ~r/{{\s*content\s*}}/, with_variables)
    case layout do
      "blank" ->
        in_layout
      _ ->
        render(in_layout, %{context|layout: "blank"}, layouts, includes)
    end
  end

end
