module Util exposing (..)

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


setAt : a -> Int -> List a -> Maybe (List a)
setAt item idx list =
  updateAt (always item) idx list


getAt : Int -> List a -> Maybe a
getAt idx list =
  case (idx, list) of
    (n, []) ->
      Nothing

    (0, x::xs) ->
      Just x

    (n, _::xs) ->
      getAt (n-1) xs


updateAt : (a -> a) -> Int -> List a -> Maybe (List a)
updateAt f idx list =
  case (idx, list) of
    (0, x::xs) ->
      Just ((f x)::xs)

    (n, []) ->
      Nothing

    (n, x::xs) ->
      updateAt f (n-1) xs
      |> Maybe.map (\ys -> x::ys)


getMaybe : String -> Maybe a -> a
getMaybe msg maybe =
  case maybe of
    Just a ->
      a

    Nothing ->
      Debug.crash msg


singleton : a -> List a
singleton x =
  [x]


getOks : List (Result a b) -> Result (List a) (List b)
getOks results =
  let
    go soFarErr soFarOk remaining =
      case remaining of
        [] ->
          case (soFarErr, soFarOk) of
            ([], xs) ->
              Ok xs

            (errs, _) ->
              Err errs

        (Ok x::xs) ->
          go soFarErr (x::soFarOk) xs

        (Err x::xs) ->
          go (x::soFarErr) soFarOk xs
  in
    go [] [] results


isJust : Maybe a -> Bool
isJust maybe =
  case maybe of
    Just a ->
      True

    Nothing ->
      False
