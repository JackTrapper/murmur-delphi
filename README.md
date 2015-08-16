# murmur-delphi
Murmur hash for Delphi

MurmurHash is a fast, non-cryptographic, hash, suitable for hash tables.

It comes in three variants:

- hash result of 32 bits
- hash result of 128 bits, optimized for x86 architecture
- hash result of 128 bits, optimized for x64 architecture


Sample Usage
----------------

In its simplest form, it can be used to generate the hash for a string:

    var 
      hash: Cardinal;

    hash := TMurmur3.HashString32('Customer_12793', $5caff01d);
      
But it can also support any other kind of data:

    var 
      hash: Cardinal
      find: WIN32_FIND_DATA;
      
    hash := TMurmur3.HashData32(find, SizeOf(WIN32_FIND_DATA), $ba5eba11);
    
    
