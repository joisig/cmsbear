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
    note = note
    |> replace_image_links()
    |> replace_file_links()
    {:ok, html, _} = Earmark.as_html(note)
    html
  end

  def tags(note) do
    Regex.scan(~r/\#[a-z0-9-_\/]+/, note) |> Enum.flat_map(&(&1))
  end
end
