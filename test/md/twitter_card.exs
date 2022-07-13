defmodule Md.TwitterCard.Test do
  use ExUnit.Case

  @url "https://aleksei.substack.com/p/--ed0"

  test "downloads card properly" do
    download_cards? = Application.get_env(:md, :download_cards, false)
    Application.put_env(:md, :download_cards, true)

    assert [
             {:p, nil,
              [
                {:a, %{href: "https://aleksei.substack.com/p/--ed0"},
                 [
                   {:figure, %{class: "card"},
                    [
                      {:img,
                       %{
                         alt: nil,
                         src:
                           "https://substackcdn.com/image/fetch/w_1200,h_600,c_limit,f_jpg,q_auto:good,fl_progressive:steep/https%3A%2F%2Fbucketeer-e05bbc84-baa3-437e-9518-adb32be77984.s3.amazonaws.com%2Fpublic%2Fimages%2F24f5f771-35f3-4a02-8254-ef78bab6a794_3648x2736.jpeg"
                       }, []},
                      {:figcaption, %{},
                       [
                         {:b, %{class: "card-title"}, ["Уроки рифмовки "]},
                         {:br, %{}, []},
                         {:span, %{class: "card-description"},
                          [
                            "Давайте я на примере незамысловатой шутейки покажу, как можно легко подстроиться под разную стилистику в стихотворных формах. Наткнулся вот я давеча на такой твит и решил сострить. Более-менее удачно острить я умею только плебейским хореем, поэтому получилось вот что:"
                          ]}
                       ]}
                    ]}
                 ]}
              ]}
           ] == Md.parse(@url).ast

    Application.put_env(:md, :download_cards, download_cards?)
  end
end
