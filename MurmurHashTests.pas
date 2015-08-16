unit MurmurHashTests;

interface

uses
	TestFramework, SysUtils, Murmur;

type
	TMurmur3Tests = class(TTestCase)
	protected
		FFreq: Int64;
		procedure SetUp; override;
		procedure TearDown; override;
	published
		procedure SelfTest_32_CanonicalSMHasher; //Canonical SMHasher 32-bit
		procedure SelfTest_32_TestVectors; //useful test vectors of 32-bit
	end;


implementation

uses
	Types, Windows;

{$IFNDEF Unicode}
type
	TBytes = TByteDynArray; //Added sometime in Delphi. If you have Unicode then you probably already have TBytes
{$ENDIF}

function HexStringToBytes(s: string): TBytes;
var
	i, j: Integer;
	n: Integer;
begin
	for i := Length(s) downto 1 do
	begin
		if s[i] = ' ' then
			Delete(s, i, 1);
	end;

	SetLength(Result, Length(s) div 2);

	i := 1;
	j := 0;
	while (i < Length(s)) do
	begin
		n := StrToInt('0x'+s[i]+s[i+1]);
		Result[j] := n;
		Inc(i, 2);
		Inc(j, 1);
	end;
end;


{ TMurmur3Tests }

procedure TMurmur3Tests.SelfTest_32_CanonicalSMHasher;
const
	Expected: LongWord = $B0F57EE3;
var
	key: array[0..255] of Byte; //256 hashes
	hashes: array[0..256] of Longword; //result of each of the 256 hashes
	i: Integer;
	actual: LongWord;
	t1, t2: Int64;
begin
	{
		The canonical Murmur3 test is to perform multiple hashes, then hash the result of the hashes.

		MurmurHash3.cpp
			https://github.com/rurban/smhasher/blob/f0b9ef8b08a5c27cc5791e888358119875a22ba0/MurmurHash3.cpp
		KeySetTest.cpp - VerificationTest(...)
			https://github.com/rurban/smhasher/blob/9c9619c3beef4241e8e96305fbbee3ec069d3081/KeysetTest.cpp

		Expected Result: 0xB0F57EE3
			main.cpp
			https://github.com/rurban/smhasher/blob/9c9619c3beef4241e8e96305fbbee3ec069d3081/main.cpp
	}
	(*
		Hash keys of the form {0}, {0,1}, {0,1,2}... up to N=255,
		using 256-N as the seed

		Key	              Seed         Hash
		==================  ===========  ==========
		00                  0x00000100   0x........
		00 01               0x000000FF   0x........
		00 01 02            0x000000FE   0x........
		00 01 02 03         0x000000FD   0x........
		...
		00 01 02 ... FE     0x00000002   0x........
		00 01 02 ... FE FF  0x00000001   0x........

		And then hash the concatenation of the 255 computed hashes
	*)
	if not QueryPerformanceCounter({out}t1) then
		t1 := 0;
	for i := 0 to 255 do
	begin
		key[i] := Byte(i);
		hashes[i] := TMurmur3.HashData32(key[0], i, 256-i);
	end;

	actual := TMurmur3.HashData32(hashes[0], 256*SizeOf(Longword), 0);

	if not QueryPerformanceCounter({out}t2) then
		t2 := 0;

	Status('Test completed in '+FloatToStrF((t2-t1)/FFreq*1000000, ffFixed, 15, 3)+' µs');

	CheckEquals(Expected, Actual, 'Murmur3_32 SMHasher test');
end;

procedure TMurmur3Tests.SelfTest_32_TestVectors;
var
	ws: UnicodeString;
	t1, t2: Int64;

	procedure t(const KeyHexString: string; Seed: LongWord; Expected: LongWord);
	var
		actual: LongWord;
		key: TByteDynArray;
	begin
		key := HexStringToBytes(KeyHexString);

		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur3.HashData32(Pointer(key)^, Length(Key), Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

		Status('Hashed '+KeyHexString+' in '+FloatToStrF((t2-t1)/FFreq*1000000, ffFixed, 15, 3)+' µs');

		CheckEquals(Expected, Actual, Format('Key: %s. Seed: 0x%.8x', [KeyHexString, Seed]));
	end;

	procedure TestString(const Value: UnicodeString; Seed: LongWord; Expected: LongWord);
	var
		actual: LongWord;
		i: Integer;
		safeValue: string;
	begin
		if not QueryPerformanceCounter(t1) then t1 := 0;

		actual := TMurmur3.HashString32(Value, Seed);

		if not QueryPerformanceCounter(t2) then t2 := 0;

		//Replace #0 with '#0'. Delphi's StringReplace is unable to replace strings, so we shall do it ourselves
		safeValue := '';
		for i := 1 to Length(Value) do
		begin
			if Value[i] = #0 then
				safeValue := safeValue + '#0'
			else
				safeValue := safeValue + Value[i];
		end;
		Status('Hashed "'+safeValue+'" in '+FloatToStrF((t2-t1)/FFreq*1000000, ffFixed, 15, 3)+' µs');

		CheckEquals(Expected, Actual, Format('Key: %s. Seed: 0x%.8x', [safeValue, Seed]));
	end;
const
	n: UnicodeString=''; //n=nothing.
			//Work around bug in older versions of Delphi compiler when building WideStrings
			//http://stackoverflow.com/a/7031942/12597

begin
	t('',                    0,         0); //with zero data and zero seed; everything becomes zero
	t('',                    1, $514E28B7); //ignores nearly all the math

	t('',            $FFFFFFFF, $81F16F39); //Make sure your seed is using unsigned math
	t('FF FF FF FF',         0, $76293B50); //Make sure your 4-byte chunks are using unsigned math
	t('21 43 65 87',         0, $F55B516B); //Endian order. UInt32 should end up as 0x87654321
	t('21 43 65 87', $5082EDEE, $2362F9DE); //Seed value eliminates initial key with xor

	t(   '21 43 65',         0, $7E4A8634); //Only three bytes. Should end up as 0x654321
	t(      '21 43',         0, $A0F7B07A); //Only two bytes. Should end up as 0x4321
	t(         '21',         0, $72661CF4); //Only one bytes. Should end up as 0x21

	t('00 00 00 00',         0, $2362F9DE); //Zero dword eliminiates almost all math. Make sure you don't mess up the pointers and it ends up as null
	t(   '00 00 00',         0, $85F0B427); //Only three bytes. Should end up as 0.
	t(      '00 00',         0, $30F4C306); //Only two bytes. Should end up as 0.
	t(         '00',         0, $514E28B7); //Only one bytes. Should end up as 0.


	//Easier to test strings. All strings are assumed to be UTF-8 encoded and do not include any null terminator
	TestString('', 0, 0); //empty string with zero seed should give zero
	TestString('', 1, $514E28B7);
	TestString('', $ffffffff, $81F16F39); //make sure seed value handled unsigned
	TestString(#0#0#0#0, 0, $2362F9DE); //we handle embedded nulls

	TestString('aaaa', $9747b28c, $5A97808A); //one full chunk
	TestString('a', $9747b28c, $7FA09EA6); //one character
	TestString('aa', $9747b28c, $5D211726); //two characters
	TestString('aaa', $9747b28c, $283E0130); //three characters

	//Endian order within the chunks
	TestString('abcd', $9747b28c, $F0478627); //one full chunk
	TestString('a', $9747b28c, $7FA09EA6);
	TestString('ab', $9747b28c, $74875592);
	TestString('abc', $9747b28c, $C84A62DD);

	TestString('Hello, world!', $9747b28c, $24884CBA);

	//we build it up this way to workaround a bug in older versions of Delphi that were unable to build WideStrings correctly
	ws := n+#$03C0+#$03C0+#$03C0+#$03C0+#$03C0+#$03C0+#$03C0+#$03C0; //U+03C0: Greek Small Letter Pi
	TestString(ws, $9747b28c, $D58063C1); //Unicode handling and conversion to UTF-8

	{
		String of 256 characters.
		Make sure you don't store string lengths in a char, and overflow at 255.
		OpenBSD's canonical implementation of BCrypt made this mistake
	}
	ws := StringOfChar('a', 256);
	TestString(ws, $9747b28c, $37405BDC);


	//The test vector that you'll see out there for Murmur
	TestString('The quick brown fox jumps over the lazy dog', $9747b28c, $2FA826CD);


	//The SHA2 test vectors
	TestString('abc', 0, $B3DD93FA);
	TestString('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq', 0, $EE925B90);

	//#1) 1 byte 0xbd
	t('bd', 0, $5FF4C2DA);

	//#2) 4 bytes 0xc98c8e55
	t('55 8e 8c c9', 0, $A7B55574);

	//#3) 55 bytes of zeros (ASCII character 55)
	TestString(StringOfChar('0', 55), 0, 2095704162);

	//#4) 56 bytes of zeros
	TestString(StringOfChar('0', 56), 0, 2438208104);

	//#5) 57 bytes of zeros
	TestString(StringOfChar('0', 57), 0, 1843415968);

	//#6) 64 bytes of zeros
	TestString(StringOfChar('0', 64), 0, 2811227051);

	//#7) 1000 bytes of zeros
	TestString(StringOfChar('0', 1000), 0, 4049757186);

	//#8) 1000 bytes of 0x41 ‘A’
	TestString(StringOfChar('A', 1000), 0, 296104456);

	//#9) 1005 bytes of 0x55 ‘U’
	TestString(StringOfChar('U', 1005), 0, 3970215021);
end;

procedure TMurmur3Tests.SetUp;
begin
  inherited;

	if not QueryPerformanceFrequency(FFreq) then
		FFreq := -1;
end;

procedure TMurmur3Tests.TearDown;
begin
  inherited;

end;

initialization
	TestFramework.RegisterTest('Murmur3', TMurmur3Tests.Suite);

end.
