{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}

module Cardano.ChainIndex.API where

import           Ledger            (Address)
import           Ledger.AddressMap (AddressMap)
import           Servant.API       ((:<|>), (:>), Get, JSON, NoContent, Post, ReqBody)

type API
     = "healthcheck" :> Get '[ JSON] NoContent
     :<|> "start-watching" :> ReqBody '[ JSON] Address :> Post '[ JSON] NoContent
     :<|> "watched-addresses" :> Get '[ JSON] AddressMap
