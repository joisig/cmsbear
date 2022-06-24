defmodule Cmsbear.Markup do

  @default_image_opts %{"attrib-max-width" => "100%"}

  def get_kv_section(text, section_id) do
    case Regex.named_captures(~r/^.*?```\n?(#{section_id})\n(?<lines>.*?)```.*?$/s, text) do
      nil ->
        ""
      %{"lines" => lines} ->
        lines
    end
    |> YamlElixir.read_from_string!()
  end

  def fixup_image_markup_impl(path, metadata_section \\ "") do
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
  end

  def fixup_image_markup(html) do
    Regex.replace(~r/\[image:([^]]+)\]\s*(```cmsbear-metadata.*?```)?/s, html, fn (all, path, metadata_section) ->
      case metadata_section do
        "" -> fixup_image_markup_impl(path)
        _ -> fixup_image_markup_impl(path, metadata_section)
      end
    end)
  end

  def fixup_file_markup(html) do
    Regex.replace(~r/\[file:([^\/]+\/([^]]+))]/, html, fn _, path, filename -> "Download: [#{filename}](/bfile/#{path})" end)
  end

  def note_to_html(note) do
    note = note
    |> fixup_image_markup()
    |> fixup_file_markup()
    |> strip_tags()
    {:ok, ast, _} = EarmarkParser.as_ast(note)
    {ast, metadata_sections} = split_metadata_sections(ast)
    ast
    |> handle_bold()
    |> handle_italics()
    |> handle_images_and_figures(metadata_sections)
    |> Earmark.Transform.transform()
  end

  def strip_tags(note) do
    Regex.replace(~r/\#[a-zA-Z][a-z0-9-_\/]+/, note, "")
  end

  def tags(note) do
    Regex.scan(~r/\#[a-z0-9-_\/]+/, note) |> Enum.flat_map(&(&1)) |> Enum.uniq()
  end

  # We process the ast to replace "em" with "strong" (because "Bear *boldly* goes
  # where no bear has gone before", and to find matching pairs of word-adjacent
  # slashes and change to italic (because "Bear has a certain /je ne c'est quoi/
  # to it").
  def handle_italics(ast) do
    ast
    |> walk_and_modify_ast(0, &handle_italics_impl/2)
    |> elem(0)
  end
  def handle_italics_impl(item, acc) when is_binary(item) do
    new_item = text_to_ast_list_splitting_regex(
      item,
      ~r/\/([[:graph:]].*?[[:graph:]]|[[:graph:]])\//,
      fn [_, content] ->
        {"em", [], [content], %{}}
      end
    )
    {new_item, acc}
  end
  def handle_italics_impl(item, acc), do: {item, acc}

  def handle_bold(ast) do
    ast
    |> walk_and_modify_ast(0, &handle_bold_impl/2)
    |> elem(0)
  end
  def handle_bold_impl({"em", attribs, items, annotations}, acc) do
    {{"strong", attribs, items, annotations}, acc}
  end
  def handle_bold_impl(item, acc), do: {item, acc}

  def split_metadata_sections(ast) do
    walk_and_modify_ast(ast, %{}, fn (item, acc) ->
      case item do
        {"pre", [], [{"code", [{"class", "cmsbear-metadata-" <> metadata_id}], [metadata_text], %{}}], %{}} ->
          metadata = YamlElixir.read_from_string!(metadata_text)
          {[], Map.put(acc, metadata_id, metadata)}
        text ->
          {text, acc}
      end
    end)
  end

  def handle_images_and_figures(ast, metadata_sections) do
    ast
    |> walk_and_modify_ast(metadata_sections, &handle_images_and_figures_impl/2)
    |> elem(0)
  end

  def use_figcaption_for_title_for_alt(attr) when is_map(attr) do
    figcaption = Map.get(attr, "figcaption", nil)
    title = Map.get(attr, "title", nil)
    alt = Map.get(attr, "alt", nil)
    title = case {figcaption, title} do
      {fc, nil} when is_binary(fc) -> fc
      _ -> title
    end
    alt = case {title, alt} do
      {t, nil} when is_binary(t) -> t
      _ -> alt
    end
    notnil_add_fn = fn (map, key, val) ->
      case val do
        nil -> map
        _ -> Map.put(map, key, val)
      end
    end
    attr |> notnil_add_fn.("title", title) |> notnil_add_fn.("alt", alt)
  end

  def generate_image_attributes(current_attributes, image_opts)
  when is_map(current_attributes) and is_map(image_opts) do
    # Title here is used to transmit the metadata section ID, and
    # should be empty unless the metadata specifies a title.
    current_attributes = current_attributes
    |> Map.delete("title")
    |> Map.delete("alt")

    image_opts
    |> use_figcaption_for_title_for_alt()
    |> Enum.into(@default_image_opts)
    |> Enum.flat_map(
      fn {key, val} ->
        case key do
          "attrib-" <> attrib_name -> [{attrib_name, val}]
          "title" -> [{"title", val}]
          "alt" -> [{"alt", val}]
          _ -> []
        end
      end
    )
    |> Enum.into(current_attributes)
  end

  def handle_images_and_figures_impl({"img", attributes, [], %{}} = item, acc) do
    metadata_sections = acc
    attributes = Enum.into(attributes, %{})
    case Map.get(attributes, "title", nil) do
      nil ->
        {item, acc}
      metadata_id ->
        metadata = Map.get(metadata_sections, metadata_id, %{})
        new_attributes = generate_image_attributes(attributes, metadata)
        image = {"img", Map.to_list(new_attributes), [], %{}}
        case Map.get(metadata, "figcaption", nil) do
          nil ->
            {image, acc}
          figcaption ->
            caption_id = UUID.uuid4()
            figure = {
              "figure", [{"aria-describedby", caption_id}],
              [image, {"figcaption", [{"id", caption_id}], [figcaption], %{}}],
              %{}
            }
            {figure, acc}
    #    "<figure aria-describedby='#{id}'>#{image}<figcaption id='#{id}'>#{caption}</figcaption></figure>"
        end
    end
  end
  def handle_images_and_figures_impl(item, acc), do: {item, acc}

  @doc """
  Walks an AST and allows you to process it (storing details in acc) and/or
  modify it as it is walked.

  The process_item_fn function is required. It takes two parameters, the
  single item to process (which will either be a string or a 4-tuple) and
  the accumulator, and returns a tuple {processed_item, updated_acc}.
  Returning the empty list for processed_item will remove the item processed
  the AST.

  The process_list_fn function is optional and defaults to no modification of
  items or accumulator. It takes two parameters, the list of items that
  are the sub-items of a given element in the AST (or the top-level list of
  items), and the accumulator, and returns a tuple
  {processed_items_list, updated_acc}.

  This function ends up returning {ast, acc}.
  """
  def walk_and_modify_ast(items, acc, process_item_fn, process_list_fn \\ &({&1, &2}))
  when is_list(items) and is_function(process_item_fn) and is_function(process_list_fn)
  do
    {items, acc} = process_list_fn.(items, acc)
    {ast, acc} = Enum.map_reduce(items, acc, fn (item, acc) ->
      {_item, _acc} = walk_and_modify_ast_item(item, acc, process_item_fn, process_list_fn)
    end)
    {List.flatten(ast), acc}
  end

  def walk_and_modify_ast_item(item, acc, process_item_fn, process_list_fn)
  when is_function(process_item_fn) and is_function(process_list_fn) do
    case process_item_fn.(item, acc) do
      {{type, attribs, items, annotations}, acc}
      when is_binary(type) and is_list(attribs) and is_list(items) and is_map(annotations) ->
        {items, acc} = walk_and_modify_ast(items, acc, process_item_fn, process_list_fn)
        {{type, attribs, List.flatten(items), annotations}, acc}
      {item_or_items, acc} when is_binary(item_or_items) or is_list(item_or_items) ->
        {item_or_items, acc}
    end
  end

  def text_to_ast_list_splitting_regex(item, regex, map_captures_fn)
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
