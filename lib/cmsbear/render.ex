defmodule Cmsbear.Render do

  alias Cmsbear.ReadBear

  def get_includes_used(text) do
    Regex.scan(~r/{{\s*include\s+(?<include_name>[a-zA-Z0-9-_\.]+)\s*}}/, text)
    |> Enum.map(&(&1 |> Enum.at(1)))
  end

  def get_variables_used(text) do
    Regex.scan(~r/{{\s*var\s+(?<var_name>[a-zA-Z0-9-_]+)\s*}}/, text)
    |> Enum.map(&(&1 |> Enum.at(1)))
  end

  def strip_layout_from_comment(text) do
    case Regex.named_captures(~r/(?<all>\<!--\s*layout:?\s+(?<layout>[a-zA-Z0-9_-]+)\s*--\>)/, text) do
      nil ->
        {:blank, text}
      %{"layout" => layout, "all" => text_to_strip} = captures ->
        {layout, String.replace(text, text_to_strip, "\n")}
    end
  end

  def get_layout_text(name, layouts) do
    case name do
      :blank ->
        "{{content}}"
      _ ->
        %{^name => layout_text} = layouts
        layout_text.body
    end
  end

  def load_files_and_render(text, context) when is_binary(text) and is_map(context) do
    # TODO caching of these?
    layouts = ReadBear.static_files("layout")
    includes = ReadBear.static_files("include")
    render(text, context, layouts, includes)
  end

  def render(text, context, layouts, includes)
  when is_binary(text) and is_map(context) and is_map(layouts) and is_map(includes) do
    rendered_doc = render_impl(text, context, layouts, includes)
    list_tag_re = ~r/{{\s*list_tag_with_layout\s*}}/
    latest_modification_re = ~r/{{\s*latest_itemprop_modification_date\s*}}/
    case Regex.run(list_tag_re, rendered_doc) do
      nil ->
        rendered_doc
      _ ->
        # For now just crash if these keys are not set
        %{"list_tag" => list_tag, "list_tag_layout" => list_tag_layout} = context
        notes = Cmsbear.ReadBear.notes_by_content(list_tag)
        [latest_modification_date|_] = notes |> Enum.map(&(&1.modification_date)) |> Enum.sort
        list_text = render_list(notes, list_tag_layout, layouts, includes)
        with_list = Regex.replace(list_tag_re, rendered_doc, list_text)
        {:ok, latest_itemprop_modification_date} = Timex.format(latest_modification_date, "%Y-%m-%dT%H:%M:%S+00:00", :strftime)
        with_latest_modification_date = Regex.replace(latest_modification_re, with_list, latest_itemprop_modification_date)
    end
  end

  def render_impl(text, context, layouts, includes)
  when is_binary(text) and is_map(context) and is_map(layouts) and is_map(includes) do
    with_includes = Enum.reduce(get_includes_used(text), text, fn include_name, acc ->
      include_text = render_impl(includes[include_name].body, Map.put(context, "layout", :blank), %{}, includes)
      String.replace(acc, ~r/{{\s*include\s+#{include_name}\s*}}/, include_text, [:global])
    end)

    with_variables = Enum.reduce(get_variables_used(text), with_includes, fn var_name, acc ->
      replacement = case context[var_name] do
        nil ->
          # TODO put a warning somewhere that a variable was used but not available?
          ""
        val ->
          val
      end
      String.replace(acc, ~r/{{\s*var\s+#{var_name}\s*}}/, replacement, [:global])
    end)

    {layout, without_layout_comment} = strip_layout_from_comment(with_variables)

    layout = Map.get(context, "layout", layout)
    case layout do
      :blank ->
        without_layout_comment
      _ ->
        in_layout = String.replace(get_layout_text(layout, layouts), ~r/{{\s*content\s*}}/, without_layout_comment)
        # When rendering layouts, they can only specify their parent layout as an HTML comment,
        # not via context.
        render_impl(in_layout, Map.delete(context, "layout"), layouts, includes)
    end
  end

  def render_list(notes, layout, layouts, includes)
  when is_list(notes) and is_binary(layout) and is_map(layouts) and is_map(includes) do
    Enum.map(notes, fn note ->
      context = note.front_matter |> Map.put("layout", layout)
      html = Cmsbear.Markup.note_to_html(note.text |> String.slice(0..2000))
      render_impl(html, context, layouts, includes)
    end)
    |> Enum.join("\n")
  end

end
