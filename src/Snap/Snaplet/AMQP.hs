{-# LANGUAGE ConstraintKinds     #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}

module Snap.Snaplet.AMQP
  ( initAMQP
  , runAmqp
  , mkAmqpConn
  , AmqpState   (..)
  , HasAmqpConn (..)
  ) where

import           Control.Monad.State
import           Control.Monad.Trans.Reader
import           Data.Configurator
import           Data.Configurator.Types
import           Network.AMQP               (Channel, Connection,
                                             ConnectionOpts (..),
                                             closeConnection,
                                             defaultConnectionOpts, openChannel,
                                             openConnection'', plain)
import           Network.Socket             (PortNumber (..))
import           Paths_snaplet_amqp
import           Snap.Snaplet

-------------------------------------------------------------------------------
type AmqpC = (Connection, Channel)

newtype AmqpState = AmqpState { amqpConn :: AmqpC }

-------------------------------------------------------------------------------
class MonadIO m => HasAmqpConn m where
    getAmqpConn :: m AmqpC

instance HasAmqpConn (Handler b AmqpState) where
    getAmqpConn = gets amqpConn

instance MonadIO m => HasAmqpConn (ReaderT AmqpC m) where
    getAmqpConn = ask

-- | Initialize the AMQP Snaplet.
initAMQP :: SnapletInit b AmqpState
initAMQP = makeSnaplet "amqp" description datadir $ do
    c <- mkSnapletAmqpConn

    onUnload (closeConnection $ fst c)

    return $ AmqpState c

  where
    description = "Snaplet for AMQP library"
    datadir = Just $ liftM (++"/resources/amqp") getDataDir

-------------------------------------------------------------------------------
-- | Constructs a connection in a snaplet context.
mkSnapletAmqpConn :: (MonadIO (m b v), MonadSnaplet m) => m b v AmqpC
mkSnapletAmqpConn = do
  conf <- getSnapletUserConfig
  mkAmqpConn conf

-------------------------------------------------------------------------------
-- | Constructs a connect from Config.
mkAmqpConn :: MonadIO m => Config -> m AmqpC
mkAmqpConn conf = do
  host  <- liftIO $ require conf "host"
  port  <- liftIO $ require conf "port"
  vhost <- liftIO $ require conf "vhost"
  login <- liftIO $ require conf "login"
  pass  <- liftIO $ require conf "password"

  let connOpts = defaultConnectionOpts
                   { coServers = [(host, (fromInteger port))]
                   , coVHost   = vhost
                   , coAuth    = [plain login pass]
                   }

  conn  <- liftIO $ openConnection'' connOpts
  chan  <- liftIO $ openChannel conn

  return (conn, chan)

-------------------------------------------------------------------------------
-- | Runs an AMQP action in any monad with a HasAmqpConn instance.
runAmqp :: (HasAmqpConn m) => (AmqpC -> b) -> m b
runAmqp action = getAmqpConn >>= return . action
