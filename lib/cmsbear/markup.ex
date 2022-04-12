defmodule Cmsbear.Markup do
  def replace_image_links(html) do
    Regex.replace(~r/\[image:([^]]+)]/, html, fn _, path -> "<img src='/bimg/#{path}' width=100%/>" end)
  end

  def replace_file_links(html) do
    Regex.replace(~r/\[file:([^\/]+\/([^]]+))]/, html, fn _, path, filename -> "<a href='/bfile/#{path}'>#{filename}</a>" end)
  end

  def note_to_html(note) do
    {:ok, html, _} = Earmark.as_html(note)
    html |> replace_image_links() |> replace_file_links()
  end

  def tags(note) do
    Regex.scan(~r/\#[a-z\/]+/, note) |> Enum.flat_map(&(&1))
  end
end
