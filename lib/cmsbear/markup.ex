defmodule Cmsbear.Markup do

  def get_kv_section(text, section_id) do
    front_matter = case Regex.named_captures(~r/^.*?```\n?(#{section_id})\n(?<lines>.*?)```.*?$/s, text) do
      nil ->
        []
      %{"lines" => lines} ->
        String.split(lines, "\n")
    end
    |> Enum.flat_map(fn line ->
      case Regex.named_captures(~r/\s*(?<key>[a-zA-Z0-9-_]+):\s*(?<val>.*)/, line) do
        nil ->
          []
        %{"key" => key, "val" => val} ->
          [{key, val}]
      end
    end)
    |> Enum.into(%{})
  end

  def generate_image_attribs(image_opts) do
    attribs = Enum.flat_map(
      image_opts |> Enum.into(%{"attrib-max-width" => "100%"}),
      fn {key, val} ->
        case key do
          "attrib-" <> attrib_name -> [{attrib_name, val}]
          "alt" -> [{"alt", val}]
          _ -> []
        end
      end)
    |> Enum.map(fn {key, val} -> "#{key}='#{val}'" end)
    |> Enum.join(" ")
  end

  def generate_image_html(path, image_opts) do
    image_attribs = generate_image_attribs(image_opts)
    image = "<img src='/bimg/#{path}' #{image_attribs} />"
    "<p>" <>
    case Map.get(image_opts, "figcaption", nil) do
      nil ->
        image
      caption ->
        id = UUID.uuid4()
        "<figure aria-describedby='#{id}'>#{image}<figcaption id='#{id}'>#{caption}</figcaption></figure>"
    end
    <> "</p>"
  end

  def replace_image_links(html) do
    Regex.replace(~r/\[image:([^]]+)\]\s*(```cmsbear-image.*?```)?/s, html, fn (all, path, image_section) ->
      case image_section do
        "" -> generate_image_html(path, %{})
        _ -> generate_image_html(path, get_kv_section(image_section, "cmsbear-image"))
      end
      <> "\n"  # Magic linebreak so Earmark doesn't discard the rest of the line
    end)
  end

  def replace_file_links(html) do
    Regex.replace(~r/\[file:([^\/]+\/([^]]+))]/, html, fn _, path, filename -> "<a href='/bfile/#{path}'>#{filename}</a>\n" end)
  end

  def note_to_html(note) do
    # TODO replace replace_xyz hacks with ast traversals
    note = note
    |> replace_image_links()
    |> replace_file_links()
    |> without_tags()
    {:ok, ast, _} = EarmarkParser.as_ast(note)
    ast
    |> process_ast()
    |> Earmark.Transform.transform()
  end

  def without_tags(note) do
    Regex.replace(~r/\#[a-zA-Z][a-z0-9-_\/]+/, note, "")
  end

  def tags(note) do
    Regex.scan(~r/\#[a-z0-9-_\/]+/, note) |> Enum.flat_map(&(&1))
  end

  # We process the ast to replace "em" with "strong" (because "Bear *really* likes fish",
  # and to find matching pairs of word-adjacent slashes and change to italic (because
  # Bear "has a certain /je ne c'est quoi/ to it").
  def process_ast(items) do
    Enum.map(items, fn item -> process_ast_item(item) end)
  end

  def process_ast_item(item) when is_binary(item) do
    re_italic_parts = ~r/\/([[:graph:]].*?[[:graph:]])\//
    italic_parts = Regex.scan(re_italic_parts, item)
    |> Enum.map(fn [_, content] ->
      {"em", [], [content], %{}}
    end)
    other_parts = Regex.split(re_italic_parts, item)
    case Regex.scan(re_italic_parts, item, return: :index) do
      [[{0, _}|_rest]|_rest2] ->
        zigzag_lists(italic_parts, other_parts)
      [_|_] ->
        zigzag_lists(other_parts, italic_parts)
      _ ->
        item
    end
  end
  def process_ast_item({"em", attribs, items, annotations}) do
    process_ast_item({"strong", attribs, items, annotations})
  end
  def process_ast_item({type, attribs, items, annotations})
  when is_binary(type) and is_list(attribs) and is_list(items) and is_map(annotations) do
    {type, attribs, process_ast(items), annotations}
  end

  def zigzag_lists(first, second, acc \\ [])
  def zigzag_lists([], [], acc) do
    Enum.reverse(acc)
  end
  def zigzag_lists([first|first_rest], second, acc) do
    # Note that there will be no match for an empty 'first' list if 'second' is not empty,
    # and this for our use case is on purpose - the lists should either be equal in
    # length, or the first list as initially passed into the function should be one longer.
    zigzag_lists(second, first_rest, [first|acc])
  end
end
