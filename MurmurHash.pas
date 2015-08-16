unit Murmur;

interface

{$IFNDEF Unicode}
type
	UnicodeString = WideString;
	UInt64 = Int64;
{$ENDIF}


type
	TMurmur3 = class(TObject)
	protected
		class function HashData128_x86(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
		class function HashData128_x64(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;

		class function HashData128(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
		class function HashString128(const Key: UnicodeString; const Seed: LongWord): UInt64;
	public
		class function HashData32(const Key; KeyLen: LongWord; const Seed: LongWord): LongWord;
		class function HashString32(const Key: UnicodeString; const Seed: LongWord): LongWord;

	end;

implementation

uses
	SysUtils, Windows
{$IFDEF UnitTests}, MurmurHashTests{$ENDIF};

function LRot32(X: LongWord; c: Byte): LongWord;
begin
	Result := (X shl c) or (X shr (32-c));
end;

function WideCharToUtf8(const Source: PWideChar; nChars: Integer): AnsiString;
var
	strLen: Integer;
begin
	if nChars = 0 then
	begin
		Result := '';
		Exit;
	end;

	// Determine real size of destination string, in bytes
	strLen := WideCharToMultiByte(CP_UTF8, 0, Source, nChars, nil, 0, nil, nil);
	if strLen = 0 then
		RaiseLastOSError;

	// Allocate memory for destination string
	SetLength(Result, strLen);

	// Convert source UTF-16 string (UnicodeString) to the destination using the code-page
	strLen := WideCharToMultiByte(CP_UTF8, 0, Source, nChars, PAnsiChar(Result), strLen, nil, nil);
	if strLen = 0 then
		RaiseLastOSError;
end;

{ TMurmur3 }

{$OVERFLOWCHECKS OFF}
class function TMurmur3.HashData128(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
begin
{$IFDEF CPUX64}
	Result := TMurmur3.HashData128_x64(Key, KeyLen, Seed);
{$ELSE}
	Result := TMurmur3.HashData128_x86(Key, KeyLen, Seed);
{$ENDIF}
end;

class function TMurmur3.HashData32(const Key; KeyLen: LongWord; const Seed: LongWord): LongWord;
var
	hash: LongWord;
	len: LongWord;
	k: LongWord;
	i: Integer;
	keyBytes: PByteArray;

const
	c1 = $cc9e2d51;
	c2 = $1b873593;
	r1 = 15;
	r2 = 13;
	m = 5;
	n = $e6546b64;
begin
{
	Murmur3 32-bit
		https://github.com/rurban/smhasher/blob/master/MurmurHash3.cpp
		http://code.google.com/p/smhasher/source/browse/
}
	keyBytes := PByteArray(@Key);

	// Initialize the hash
	hash := seed;
	len := KeyLen;

	i := 0;

	// Mix 4 bytes at a time into the hash
	while(len >= 4) do
	begin
		k := PLongWord(@(keyBytes[i]))^;

		k := k*c1;
		k := LRot32(k, r1);
		k := k*c2;

		hash := hash xor k;
		hash := LRot32(hash, r2);
		hash := hash*m + n;

		Inc(i, 4);
		Dec(len, 4);
	end;

	{	Handle the last few bytes of the input array
			Key: ... $69 $18 $2f
	}
	if len > 0 then
	begin
		Assert(len <= 3);
		k := 0;

		//Pack last few bytes into k
		if len = 3 then
			k := k or (keyBytes[i+2] shl 16);
		if len >= 2 then
			k := k or (keyBytes[i+1] shl 8);
		k := k or (keyBytes[i]);

		k := k*c1;
		k := LRot32(k, r1);
		k := k*c2;

		hash := hash xor k;
	end;

	// Finalization
	hash := hash xor keyLen;

	hash := hash xor (hash shr 16);
	hash := hash * $85ebca6b;
	hash := hash xor (hash shr 13);
	hash := hash * $c2b2ae35;
	hash := hash xor (hash shr 16);

	Result := hash;
end;
{$OVERFLOWCHECKS ON} 

class function TMurmur3.HashString128(const Key: UnicodeString; const Seed: LongWord): UInt64;
var
	s: AnsiString; //UTF-8 version of Key
begin
	s := WideCharToUtf8(PWideChar(Key), Length(Key));

	Result := TMurmur3.HashData128(Pointer(s)^, Length(s)*SizeOf(AnsiChar), Seed);
end;

class function TMurmur3.HashString32(const Key: UnicodeString; const Seed: LongWord): LongWord;
var
	s: AnsiString; //UTF-8 version of Key
begin
	s := WideCharToUtf8(PWideChar(Key), Length(Key));

	Result := TMurmur3.HashData32(Pointer(s)^, Length(s)*SizeOf(AnsiChar), Seed);
end;

class function TMurmur3.HashData128_x64(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
begin
	raise Exception.Create('Not implemented');
end;

class function TMurmur3.HashData128_x86(const Key; KeyLen: LongWord; const Seed: LongWord): UInt64;
begin
	raise Exception.Create('Not implemented');
end;

end.
