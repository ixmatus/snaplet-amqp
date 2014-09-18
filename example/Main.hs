{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TemplateHaskell   #-}

module Main where

------------------------------------------------------------------------------
import           Control.Lens
import           Data.ByteString.Char8 as C8
import           Network.AMQP
import           Snap
import           Snap.Snaplet.AMQP

------------------------------------------------------------------------------
data App = App
    { _amqp :: Snaplet AmqpState
    }

makeLenses ''App

instance HasAmqpConn (Handler b App) where
    getAmqpConn = with amqp getAmqpConn

------------------------------------------------------------------------------
-- | The application's routes.
routes :: [(ByteString, Handler App App ())]
routes = [ ("/"   , writeText "hello")
         , ("test", fooHandler)
         ]

fooHandler :: Handler App App ()
fooHandler = do
    let serverQueue = "myQueue"
        exchange'   = "myExchange"
        routingKey  = "myKey"

    _ <- runAmqp $ \(_, chan) -> do
        _ <- declareQueue chan newQueue {queueName = serverQueue}

        declareExchange chan newExchange {exchangeName = exchange', exchangeType = "headers"}
        bindQueue       chan serverQueue exchange' routingKey

        -- Update all dimmers in the group with the NEW group configuration
        publishMsg chan exchange' routingKey
            newMsg {msgBody = "AMQP Snaplet!",
                    msgDeliveryMode = Just Persistent}

    modifyResponse $ setResponseCode 204


------------------------------------------------------------------------------
-- | The application initializer.
app :: SnapletInit App App
app = makeSnaplet "app" "An snaplet example application." Nothing $ do
    m <- nestSnaplet "amqp" amqp $ initAMQP
    addRoutes routes
    return $ App m


main :: IO ()
main = serveSnaplet defaultConfig app
