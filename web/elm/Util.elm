module Util where

insertAt : a -> Int -> List a -> Maybe (List a)
insertAt item idx list =
  case (idx, list) of
    (0, xs) ->
      Just (item::xs)

    (n, []) ->
      Nothing

    (n, x::xs) ->
      insertAt item (n-1) xs
      |> Maybe.map (\ys -> x::ys)


removeAt : Int -> List a -> List a
removeAt idx list =
  list
  |> List.indexedMap (,)
  |> List.filter (\(i, _) -> i /= idx)
  |> List.map snd
