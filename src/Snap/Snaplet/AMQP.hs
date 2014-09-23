{-# LANGUAGE ConstraintKinds     #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}

module Snap.Snaplet.AMQP
  ( initAMQP
  , runAmqp
  , mkAmqpPool
  , AmqpState   (..)
  , HasAmqpPool (..)
  ) where

import           Control.Monad.State
import           Control.Monad.Trans.Reader
import           Data.Configurator
import           Data.Configurator.Types
import           Data.Pool
import           Network.AMQP               (Channel, Connection,
                                             ConnectionOpts (..),
                                             closeConnection,
                                             defaultConnectionOpts, openChannel,
                                             openConnection'', plain)
import           Paths_snaplet_amqp
import           Snap.Snaplet

-------------------------------------------------------------------------------
type AmqpPool = Pool Connection

newtype AmqpState = AmqpState { amqpPool :: AmqpPool }

-------------------------------------------------------------------------------
class MonadIO m => HasAmqpPool m where
    getAmqpPool :: m AmqpPool

instance HasAmqpPool (Handler b AmqpState) where
    getAmqpPool = gets amqpPool

instance MonadIO m => HasAmqpPool (ReaderT AmqpPool m) where
    getAmqpPool = ask

-- | Initialize the AMQP Snaplet.
initAMQP :: SnapletInit b AmqpState
initAMQP = makeSnaplet "amqp" description datadir $ do
    p <- mkSnapletAmqpPool

    onUnload (destroyAllResources p)

    return $ AmqpState p

  where
    description = "Snaplet for AMQP library"
    datadir = Just $ liftM (++"/resources/amqp") getDataDir

-------------------------------------------------------------------------------
-- | Constructs a connection in a snaplet context.
mkSnapletAmqpPool :: (MonadIO (m b v), MonadSnaplet m) => m b v AmqpPool
mkSnapletAmqpPool = do
  conf <- getSnapletUserConfig
  mkAmqpPool conf

-------------------------------------------------------------------------------
-- | Constructs a connect from Config.
mkAmqpPool :: MonadIO m => Config -> m AmqpPool
mkAmqpPool conf = do
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
  return =<< liftIO $ createPool (openConnection'' connOpts) closeConnection 1 30 10

-------------------------------------------------------------------------------
-- | Runs an AMQP action in any monad with a HasAmqpPoolonn instance.
runAmqp :: (HasAmqpPool m) => ((Connection, Channel) -> b) -> m b
runAmqp action = do
    pool <- getAmqpPool
    return =<< liftIO $ withResource pool $ \conn -> do
        chan <- openChannel conn
        return $ action (conn, chan)
