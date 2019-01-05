module Node.Buffer.Mutable
 ( class MutableBuffer
 , create
 , freeze
 , thaw
 , fromArray
 , fromString
 , fromArrayBuffer
 , toArrayBuffer
 , read
 , readString
 , toString
 , write
 , writeString
 , toArray
 , getAtOffset
 , setAtOffset
 , size
 , concat
 , concat'
 , copy
 , fill
 , EffectBuffer
 , STBuffer
 , runST
 ) where

import Prelude

import Control.Monad.ST (ST, kind Region)
import Control.Monad.ST as ST
import Data.ArrayBuffer.Types (ArrayBuffer)
import Data.Maybe (Maybe)
import Effect (Effect)
import Node.Buffer (Buffer, BufferValueType, Octet, Offset)
import Node.Buffer as Buffer
import Node.Encoding (Encoding, encodingToNode)
import Unsafe.Coerce (unsafeCoerce)

-- | A type class for mutable buffers `buf` where operations on those buffers are
-- | represented by a particular monadic effect type `m`.
class Monad m <= MutableBuffer buf m | m -> buf, buf -> m where

  -- | Creates a new buffer of the specified size.
  create :: Int -> m buf

  -- | Creates an immutable copy of a mutable buffer.
  freeze :: buf -> m Buffer

  -- | Creates a mutable copy of an immutable buffer.
  thaw :: Buffer -> m buf

  -- | Creates a new buffer from an array of octets, sized to match the array.
  fromArray :: Array Octet -> m buf

  -- | Creates a new buffer from a string with the specified encoding, sized to
  -- | match the string.
  fromString :: String -> Encoding -> m buf

  -- | Creates a buffer view from a JS ArrayByffer without copying data.
  fromArrayBuffer :: ArrayBuffer -> m buf

  -- | Copies the data in the buffer to a new JS ArrayBuffer
  toArrayBuffer :: buf -> m ArrayBuffer

  -- | Reads a numeric value from a buffer at the specified offset.
  read :: BufferValueType -> Offset -> buf -> m Int

  -- | Reads a section of a buffer as a string with the specified encoding.
  readString :: Encoding -> Offset -> Offset -> buf -> m String

  -- | Reads the buffer as a string with the specified encoding.
  toString :: Encoding -> buf -> m String

  -- | Writes a numeric value to a buffer at the specified offset.
  write :: BufferValueType -> Int -> Offset -> buf -> m Unit

  -- | Writes octets from a string to a buffer at the specified offset. Multi-byte
  -- | characters will not be written to the buffer if there is not enough capacity
  -- | to write them fully. The number of bytes written is returned.
  writeString :: Encoding -> Offset -> Int -> String -> buf -> m Int

  -- | Creates an array of octets from a buffer's contents.
  toArray :: buf -> m (Array Octet)

  -- | Reads an octet from a buffer at the specified offset.
  getAtOffset :: Offset -> buf -> m (Maybe Octet)

  -- | Writes an octet in the buffer at the specified offset.
  setAtOffset :: Octet -> Offset -> buf -> m Unit

  -- | Returns the size of a buffer.
  size :: buf -> m Int

  -- | Concatenates a list of buffers.
  concat :: Array buf -> m buf

  -- | Concatenates a list of buffers, combining them into a new buffer of the
  -- | specified length.
  concat' :: Array buf -> Int -> m buf

  -- | Copies a section of a source buffer into a target buffer at the specified
  -- | offset, and returns the number of octets copied.
  copy :: Offset -> Offset -> buf -> Offset -> buf -> m Int

  -- | Fills a range in a buffer with the specified octet.
  fill :: Octet -> Offset -> Offset -> buf -> m Unit

-- | A reference to a mutable buffer for use with `Effect`
foreign import data EffectBuffer :: Type

-- | A reference to a mutable buffer for use with `ST`
-- |
-- | The type parameter represents the memory region which the buffer belongs to.
foreign import data STBuffer :: Region -> Type

-- | Runs an effect creating an `STBuffer` then freezes the buffer and returns
-- | it, without unneccessary copying.
runST :: forall h. ST h (STBuffer h) -> Buffer
runST st = ST.run (unsafeCoerce st)

instance mutableBufferEffect :: MutableBuffer EffectBuffer Effect where
  create = createImpl
  freeze = copyAllImpl
  thaw = copyAllImpl
  fromArray = fromArrayImpl
  fromString = fromStringImpl
  fromArrayBuffer = fromArrayBufferImpl
  toArrayBuffer = toArrayBufferImpl
  read = readImpl
  readString = readStringImpl
  toString = toStringImpl
  write = writeImpl
  writeString = writeStringImpl
  toArray = toArrayImpl
  getAtOffset = getAtOffsetImpl
  setAtOffset = setAtOffsetImpl
  size = sizeImpl
  concat = concatImpl
  concat' = concatImpl'
  copy = copyImpl
  fill = fillImpl

instance mutableBufferST :: MutableBuffer (STBuffer h) (ST h) where
  create = createImpl
  freeze = copyAllImpl
  thaw = copyAllImpl
  fromArray = fromArrayImpl
  fromString = fromStringImpl
  fromArrayBuffer = fromArrayBufferImpl
  toArrayBuffer = toArrayBufferImpl
  read = readImpl
  readString = readStringImpl
  toString = toStringImpl
  write = writeImpl
  writeString = writeStringImpl
  toArray = toArrayImpl
  getAtOffset = getAtOffsetImpl
  setAtOffset = setAtOffsetImpl
  size = sizeImpl
  concat = concatImpl
  concat' = concatImpl'
  copy = copyImpl
  fill = fillImpl

usingFromFrozen :: forall buf m a. (Buffer -> a) -> buf -> m a
usingFromFrozen f buf = unsafeCoerce \_ -> f $ unsafeCoerce buf

usingToFrozen :: forall buf m a. (a -> Buffer) -> a -> m buf
usingToFrozen f x = unsafeCoerce \_ -> unsafeCoerce $ f x

createImpl :: forall buf m. Int -> m buf
createImpl = usingToFrozen Buffer.create

foreign import copyAllImpl :: forall a buf m. a -> m buf

fromArrayImpl :: forall buf m. Array Octet -> m buf
fromArrayImpl = usingToFrozen Buffer.fromArray

fromStringImpl :: forall buf m. String -> Encoding -> m buf
fromStringImpl s = usingToFrozen $ Buffer.fromString s

fromArrayBufferImpl :: forall buf m. ArrayBuffer -> m buf
fromArrayBufferImpl = usingToFrozen Buffer.fromArrayBuffer

toArrayBufferImpl :: forall buf m. buf -> m ArrayBuffer
toArrayBufferImpl = usingFromFrozen Buffer.toArrayBuffer

readImpl :: forall buf m. BufferValueType -> Offset -> buf -> m Int
readImpl t o = usingFromFrozen $ Buffer.read t o

readStringImpl :: forall buf m. Encoding -> Offset -> Offset -> buf -> m String
readStringImpl m o o' = usingFromFrozen $ Buffer.readString m o o'

toStringImpl :: forall buf m. Encoding -> buf -> m String
toStringImpl m = usingFromFrozen $ Buffer.toString m

writeImpl :: forall buf m. BufferValueType -> Int -> Offset -> buf -> m Unit
writeImpl = writeInternal <<< show

foreign import writeInternal :: forall buf m. String -> Int -> Offset -> buf -> m Unit

writeStringImpl :: forall buf m. Encoding -> Offset -> Int -> String -> buf -> m Int
writeStringImpl = writeStringInternal <<< encodingToNode

foreign import writeStringInternal ::
  forall buf m. String -> Offset -> Int -> String -> buf -> m Int

toArrayImpl :: forall buf m. buf -> m (Array Octet)
toArrayImpl = usingFromFrozen Buffer.toArray

getAtOffsetImpl :: forall buf m. Offset -> buf -> m (Maybe Octet)
getAtOffsetImpl o = usingFromFrozen $ Buffer.getAtOffset o

foreign import setAtOffsetImpl :: forall buf m. Octet -> Offset -> buf -> m Unit

sizeImpl :: forall buf m. buf -> m Int
sizeImpl = usingFromFrozen Buffer.size

concatImpl :: forall buf m. Array buf -> m buf
concatImpl arrs = unsafeCoerce \_ -> Buffer.concat (unsafeCoerce arrs)

concatImpl' :: forall buf m. Array buf -> Int -> m buf
concatImpl' arrs n = unsafeCoerce \_ -> Buffer.concat' (unsafeCoerce arrs) n

foreign import copyImpl :: forall buf m. Offset -> Offset -> buf -> Offset -> buf -> m Int

foreign import fillImpl :: forall buf m. Octet -> Offset -> Offset -> buf -> m Unit
