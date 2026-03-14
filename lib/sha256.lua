-- sha256.lua (NbWSdspn), by graypinkfurball
-- Based on Anavrins sha256 (6UV4qfNF)
-- MIT License

local function to_hex(bytes)
  return ("%02x"):rep(#bytes):format(table.unpack(bytes))
end

local function chunk_digestive(options)
  local chunk_size = options.chunk_size
  local update_chunk = options.update_chunk -- function(chunk, i)
  local digest_chunk = options.digest_chunk -- function(partial_chunk, total_length)
  local init = options.init -- optional: function(digestive)

  local digestive = {}
  
  local finished = false
  local total_length = 0
  local partial_chunk, result

  -- TODO: allow passing sub indices
  local function update(message)
    if type(message) == "string" then message = table.pack(message:byte(1, -1)) end
    local n = message.n or #message

    total_length = total_length + n

    local n1 = 0
    if partial_chunk then
      n1 = math.min(n, chunk_size - #partial_chunk)
      table.move(message, 1, n1, #partial_chunk+1, partial_chunk)
      -- FIXME: message cannot have nils between 1 and n1, or there will be a desync between total_length and partial chunk, where all data after first nil is eaten
      -- ideally message data should never contain nils and input validation would be too costly
      if #partial_chunk < chunk_size then return end

      update_chunk(partial_chunk, 1)
      partial_chunk = nil
    end

    local n2 = n - (n-n1) % chunk_size
    for k = n1+1, n2, chunk_size do
      update_chunk(message, k)
    end

    if n2 < n then
      partial_chunk = {}
      table.move(message, n2+1, n, 1, partial_chunk)
    end

    return digestive
  end

  local function digest(message)
    if message then update(message) end
    if not finished then
      finished = true
      result = digest_chunk(partial_chunk, total_length)
      partial_chunk = nil
    end
    return result
  end

  local function hexdigest(message)
    return to_hex(digest(message))
  end

  digestive.update = update
  digestive.digest = digest
  digestive.hexdigest = hexdigest
  if init then init(digestive) end
  return digestive
end

local band = bit32.band
local bxor = bit32.bxor
local rrotate = bit32.rrotate
local rshift = bit32.rshift

local function write_u32(b, i, n)
  b[i] = rshift(n, 24)
  b[i+1] = band(rshift(n, 16), 0xFF)
  b[i+2] = band(rshift(n, 8), 0xFF)
  b[i+3] = band(n, 0xFF)
end

local function write_u64(b, i, n)
  write_u32(b, i, math.floor(n / 0x100000000))
  write_u32(b, i+4, n)
end

local k = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function internal_sha256()
  local h0, h1, h2, h3, h4, h5, h6, h7
  local w = {}
  local function update_chunk(chunk, i)
    for j = 1, 16 do
      w[j] = chunk[i] * 0x1000000 + chunk[i+1] * 0x10000 + chunk[i+2] * 0x100 + chunk[i+3]
      i = i + 4
    end

    for j = 17, 64 do
      local u, v = w[j-15], w[j-2]
      local s0 = bxor(rrotate(u, 7), rrotate(u, 18), rshift(u, 3))
      local s1 = bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
      w[j] = (w[j-16] + s0 + w[j-7] + s1)
    end

    local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
    for j = 1, 64 do
      local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
      local ch = bxor(band(e, f), band(0xFFFFFFFF - e, g))
      local temp1 = h + S1 + ch + k[j] + w[j]

      local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
      local maj = bxor(band(a, b), band(a, c), band(b, c))
      local temp2 = S0 + maj

      h = g
      g = f
      f = e
      e = d + temp1
      d = c
      c = b
      b = a
      a = temp1 + temp2
    end

    h0 = (h0 + a) % 0x100000000
    h1 = (h1 + b) % 0x100000000
    h2 = (h2 + c) % 0x100000000
    h3 = (h3 + d) % 0x100000000
    h4 = (h4 + e) % 0x100000000
    h5 = (h5 + f) % 0x100000000
    h6 = (h6 + g) % 0x100000000
    h7 = (h7 + h) % 0x100000000
  end

  local function digest_chunk(partial_chunk, total_length)
    if total_length > 0x4000000000000 then error("total length too large", 2) end

    local chunk = partial_chunk or {}
    chunk[#chunk+1] = 0x80

    if #chunk > 56 then
      for i = #chunk+1, 64 do chunk[i] = 0 end
      update_chunk(chunk, 1)
      chunk = {}
    end

    for i = #chunk+1, 56 do chunk[i] = 0 end
    write_u64(chunk, 57, total_length * 8)
    update_chunk(chunk, 1)

    local i = 1
    local result = {}
    local hash = { h0, h1, h2, h3, h4, h5, h6, h7 }
    for j = 1, 8 do
      write_u32(result, i, hash[j])
      i = i + 4
    end

    return result
  end

  return {
    chunk_size = 64,
    update_chunk = update_chunk,
    digest_chunk = digest_chunk,
    init = function()
      h0, h1, h2, h3, h4, h5, h6, h7 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    end,
    get_hash = function()
      return h0, h1, h2, h3, h4, h5, h6, h7
    end,
    set_hash = function(...)
      h0, h1, h2, h3, h4, h5, h6, h7 = ...
    end,
  }
end

local function sha256(message)
  local digestive = chunk_digestive(internal_sha256())
  if message then return digestive.hexdigest(message) end
  return digestive
end

local function internal_hmac(inner_pad, outer_pad)
  local hasher = internal_sha256()
  return {
    chunk_size = 64,
    update_chunk = function(chunk, i)
      hasher.update_chunk(chunk, i)
    end,
    digest_chunk = function(partial_chunk, total_length)
      return sha256().update(outer_pad).digest(hasher.digest_chunk(partial_chunk, total_length))
    end,
    init = function(digestive)
      hasher.init()
      digestive.update(inner_pad)
    end,
    hasher = hasher,
  }
end

local function make_hmac_pads(key)
  if #key > 64 then
    key = sha256().digest(key)
  elseif type(key) == "string" then
    key = table.pack(key:byte(1, -1))
  end

  local inner_pad, outer_pad = {}, {}
  for i = 1, #key do
    local n = key[i]
    inner_pad[i] = bxor(n, 0x36)
    outer_pad[i] = bxor(n, 0x5C)
  end
  for i = #key+1, 64 do
    inner_pad[i] = 0x36
    outer_pad[i] = 0x5C
  end

  return inner_pad, outer_pad
end

local function hmac(key, message)
  local digestive = chunk_digestive(internal_hmac(make_hmac_pads(key)))
  if message then return digestive.hexdigest(message) end
  return digestive
end

local function expect(value, param, ...)
  local types = { ... }
  local value_type = type(value)
  for i = 1, #types do
    if types[i] == value_type then return end
  end

  error(("bad argument for '%s' (expected %s, got %s)"):format(param, table.concat(types, "/"), value_type), 3)
end

local function wrap_digestive(digestive)
  local update, digest, hexdigest = digestive.update, digestive.digest, digestive.hexdigest
  return {
    update = function(message)
      expect(message, "message", "string", "table")
      if finished then error("digest already finished", 2) end
      return update(message)
    end,
    digest = function(message)
      expect(message, "message", "string", "table", "nil")
      if message and finished then error("digest already finished", 2) end
      return digest(message)
    end,
    hexdigest = function(message)
      expect(message, "message", "string", "table", "nil")
      if message and finished then error("digest already finished", 2) end
      return hexdigest(message)
    end,
  }
end

return {
  unchecked = {
    chunk_digestive = chunk_digestive,
    internal_sha256 = internal_sha256,
    internal_hmac = internal_hmac,
    make_hmac_pads = make_hmac_pads,
    sha256 = sha256,
    hmac = hmac,
  },
  sha256 = function(message)
    expect(message, "message", "string", "table", "nil")
    if message then return sha256(message) end
    return wrap_digestive(sha256())
  end,
  hmac = function(key, message)
    expect(key, "key", "string", "table")
    expect(message, "message", "string", "table", "nil")
    if message then return hmac(key, message) end
    return wrap_digestive(hmac(key))
  end
}
