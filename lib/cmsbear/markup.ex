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

  def generate_image_html(path, metadata_section \\ "") do
    {title_part, metadata_section} = case metadata_section do
      "" ->
        {"", ""}
      _ ->
        link_id = UUID.uuid4()
        {
          " \"#{link_id}\"",
          String.replace(metadata_section, "```cmsbear-metadata", "```cmsbear-metadata-#{link_id}")
        }
    end
    "![image](/bimg/#{path}#{title_part})\n#{metadata_section}"

    #case Map.get(image_opts, "figcaption", nil) do
    #  nil ->
    #    image
    #  caption ->
    #    id = UUID.uuid4()
    #    "<figure aria-describedby='#{id}'>#{image}<figcaption id='#{id}'>#{caption}</figcaption></figure>"
    #end
  end

  def replace_image_links(html) do
    Regex.replace(~r/\[image:([^]]+)\]\s*(```cmsbear-metadata.*?```)?/s, html, fn (all, path, metadata_section) ->
      case metadata_section do
        "" -> generate_image_html(path)
        _ -> generate_image_html(path, metadata_section)
      end
    end)
  end

  def replace_file_links(html) do
    Regex.replace(~r/\[file:([^\/]+\/([^]]+))]/, html, fn _, path, filename -> "Download: [#{filename}](/bfile/#{path})" end)
  end

  def note_to_html(note) do
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

  # We process the ast to replace "em" with "strong" (because "Bear *boldly* goes
  # where no bear has gone before", and to find matching pairs of word-adjacent
  # slashes and change to italic (because "Bear has a certain /je ne c'est quoi/
  # to it").
  def process_ast(items) do
    Enum.map(items, fn item -> process_ast_item(item) end)
  end

  def process_ast_item(item) when is_binary(item) do
    process_ast_item_splitting_regex(
      item,
      ~r/\/([[:graph:]].*?[[:graph:]]|[[:graph:]])\//,
      fn [_, content] ->
        {"em", [], [content], %{}}
      end
    )
  end
  def process_ast_item({"em", attribs, items, annotations}) do
    process_ast_item({"strong", attribs, items, annotations})
  end
  def process_ast_item({type, attribs, items, annotations})
  when is_binary(type) and is_list(attribs) and is_list(items) and is_map(annotations) do
    {type, attribs, List.flatten(process_ast(items)), annotations}
  end

  def process_ast_item_splitting_regex(item, regex, map_captures_fn)
  when is_binary(item) and is_function(map_captures_fn) do
    interest_parts = Regex.scan(regex, item)
    |> Enum.map(map_captures_fn)
    other_parts = Regex.split(regex, item)
    case Regex.scan(regex, item, return: :index) do
      [[{0, _}|_rest]|_rest2] ->
        zigzag_lists(interest_parts, other_parts)
      [_|_] ->
        zigzag_lists(other_parts, interest_parts)
      _ ->
        item
    end
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
