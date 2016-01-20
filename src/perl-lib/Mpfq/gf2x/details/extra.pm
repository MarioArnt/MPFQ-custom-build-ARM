package Mpfq::gf2x::details::extra;

use strict;
use warnings;

use Mpfq::engine::utils qw/symbol_table_of/;
use Exporter qw(import);

# our @EXPORT_OK = qw/alternatives/;
# our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub code_for_mul1_paul {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
   unsigned long hi, lo;
   unsigned long A[32];
   const unsigned long a = s2[0];
   const unsigned long b = s1[0];

   A[0] = 0;
   A[1] = a;
   A[2] = A[1] << 1;
   A[3] = A[2] ^ A[1];
   A[4] = A[2] << 1;
   A[5] = A[4] ^ A[1];
   A[6] = A[3] << 1;
   A[7] = A[6] ^ A[1];
   A[8] = A[4] << 1;
   A[9] = A[8] ^ A[1];
   A[10] = A[5] << 1;
   A[11] = A[10] ^ A[1];
   A[12] = A[6] << 1;
   A[13] = A[12] ^ A[1];
   A[14] = A[7] << 1;
   A[15] = A[14] ^ A[1];
   A[16] = A[8] << 1;
   A[17] = A[16] ^ A[1];
   A[18] = A[9] << 1;
   A[19] = A[18] ^ A[1];
   A[20] = A[10] << 1;
   A[21] = A[20] ^ A[1];
   A[22] = A[11] << 1;
   A[23] = A[22] ^ A[1];
   A[24] = A[12] << 1;
   A[25] = A[24] ^ A[1];
   A[26] = A[13] << 1;
   A[27] = A[26] ^ A[1];
   A[28] = A[14] << 1;
   A[29] = A[28] ^ A[1];
   A[30] = A[15] << 1;
   A[31] = A[30] ^ A[1];

   lo = A[b >> (64 - 4)];
   hi = lo >> (64 - 5);
   lo = (lo << 5) ^ A[(b >> (64 - 9)) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 50) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 45) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 40) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 35) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 30) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 25) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 20) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 15) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 10) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 5) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[b & 31];
   if ((a >> (64 - 1)) & 1)
       hi = hi ^ ((b & 0xef7bdef7bdef7bde) >> 1);
   if ((a >> (64 - 2)) & 1)
       hi = hi ^ ((b & 0xce739ce739ce739c) >> 2);
   if ((a >> (64 - 3)) & 1)
       hi = hi ^ ((b & 0x8c6318c6318c6318) >> 3);
   if ((a >> (64 - 4)) & 1)
       hi = hi ^ ((b & 0x842108421084210) >> 4);
   t[0] $op lo;
   t[1] $op hi;
EOF
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_paul2 {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
   _ntl_ulong hi, lo;
   _ntl_ulong A[16];
   unsigned long a = s2[0];
   unsigned long b = s1[0];

   A[0] = 0;
   A[1] = a;
   A[2] = A[1] << 1;
   A[3] = A[2] ^ A[1];
   A[4] = A[2] << 1;
   A[5] = A[4] ^ A[1];
   A[6] = A[3] << 1;
   A[7] = A[6] ^ A[1];
   A[8] = A[4] << 1;
   A[9] = A[8] ^ A[1];
   A[10] = A[5] << 1;
   A[11] = A[10] ^ A[1];
   A[12] = A[6] << 1;
   A[13] = A[12] ^ A[1];
   A[14] = A[7] << 1;
   A[15] = A[14] ^ A[1];

   lo = (A[b >> 60] << 4) ^ A[(b >> 56) & 15];
   hi = lo >> 56;
   lo = (lo << 8) ^ (A[(b >> 52) & 15] << 4) ^ A[(b >> 48) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 44) & 15] << 4) ^ A[(b >> 40) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 36) & 15] << 4) ^ A[(b >> 32) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 28) & 15] << 4) ^ A[(b >> 24) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 20) & 15] << 4) ^ A[(b >> 16) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 12) & 15] << 4) ^ A[(b >> 8) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 4) & 15] << 4) ^ A[b & 15];

   {
     _ntl_ulong tmp;
     tmp = -((a >> 63) & 1);
     tmp &= ((b & 0xfefefefefefefefe) >> 1);
     hi = hi ^ tmp;
     tmp = -((a >> 62) & 1);
     tmp &= ((b & 0xfcfcfcfcfcfcfcfc) >> 2);
     hi = hi ^ tmp;
     tmp = -((a >> 61) & 1);
     tmp &= ((b & 0xf8f8f8f8f8f8f8f8) >> 3);
     hi = hi ^ tmp;
     tmp = -((a >> 60) & 1);
     tmp &= ((b & 0xf0f0f0f0f0f0f0f0) >> 4);
     hi = hi ^ tmp;
     tmp = -((a >> 59) & 1);
     tmp &= ((b & 0xe0e0e0e0e0e0e0e0) >> 5);
     hi = hi ^ tmp;
     tmp = -((a >> 58) & 1);
     tmp &= ((b & 0xc0c0c0c0c0c0c0c0) >> 6);
     hi = hi ^ tmp;
     tmp = -((a >> 57) & 1);
     tmp &= ((b & 0x8080808080808080) >> 7);
     hi = hi ^ tmp;
   }
   t[0] $op lo;
   t[1] $op hi;
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_joerg {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
   unsigned long hi, lo;
   unsigned long A[32];
   const unsigned long a = s2[0];
   const unsigned long b = s1[0];

   A[0]=0;
   A[1]=a;
#define a1 a
   {
       const unsigned long a2 = a1 << 1;  A[2]=a2;
       {
           const unsigned long a4 = a2 << 1;  A[4]=a4;
           {
               const unsigned long a8 = a4 << 1;  A[8]=a8;
               {
                   const unsigned long a16 = a8 << 1;  A[16]=a16;
                   const unsigned long a17 = a16 ^ a;  A[17]=a17;
               }
               const unsigned long a9 = a8 ^ a;  A[9]=a9;
               {
                   const unsigned long a18 = a9 << 1;  A[18]=a18;
                   const unsigned long a19 = a18 ^ a;  A[19]=a19;
               }
           }
           const unsigned long a5 = a4 ^ a;  A[5]=a5;
           {
               const unsigned long a10 = a5 << 1;  A[10]=a10;
               {
                   const unsigned long a20 = a10 << 1;  A[20]=a20;
                   const unsigned long a21 = a20 ^ a;  A[21]=a21;
               }
               const unsigned long a11 = a10 ^ a;  A[11]=a11;
               {
                   const unsigned long a22 = a11 << 1;  A[22]=a22;
                   const unsigned long a23 = a22 ^ a;  A[23]=a23;
               }
           }
       }

       const unsigned long a3 = a2 ^ a;  A[3]=a3;
       {
           const unsigned long a6 = a3 << 1;  A[6]=a6;
           {
               const unsigned long a12 = a6 << 1;  A[12]=a12;
               {
                   const unsigned long a24 = a12 << 1;  A[24]=a24;
                   const unsigned long a25 = a24 ^ a;  A[25]=a25;
               }
               const unsigned long a13 = a12 ^ a;  A[13]=a13;
               {
                   const unsigned long a26 = a13 << 1;  A[26]=a26;
                   const unsigned long a27 = a26 ^ a;  A[27]=a27;
               }
           }
           const unsigned long a7 = a6 ^ a;  A[7]=a7;
           {
               const unsigned long a14 = a7 << 1;  A[14]=a14;
               {
                   const unsigned long a28 = a14 << 1;  A[28]=a28;
                   const unsigned long a29 = a28 ^ a;  A[29]=a29;
               }
               const unsigned long a15 = a14 ^ a;  A[15]=a15;
               {
                   const unsigned long a30 = a15 << 1;  A[30]=a30;
                   const unsigned long a31 = a30 ^ a;  A[31]=a31;
               }
           }
       }
   }
#undef a1

   lo = A[b >> (64 - 4)];
   hi = lo >> (64 - 5);
   lo = (lo << 5) ^ A[(b >> (64 - 9)) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 50) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 45) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 40) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 35) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 30) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 25) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 20) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 15) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 10) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[(b >> 5) & 31];
   hi = (hi << 5) | (lo >> 59);
   lo = (lo << 5) ^ A[b & 31];
   if ((a >> (64 - 1)) & 1)
       hi = hi ^ ((b & 0xef7bdef7bdef7bde) >> 1);
   if ((a >> (64 - 2)) & 1)
       hi = hi ^ ((b & 0xce739ce739ce739c) >> 2);
   if ((a >> (64 - 3)) & 1)
       hi = hi ^ ((b & 0x8c6318c6318c6318) >> 3);
   if ((a >> (64 - 4)) & 1)
       hi = hi ^ ((b & 0x842108421084210) >> 4);
   t[0] $op lo;
   t[1] $op hi;
EOF
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_paul2_reversed {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
   _ntl_ulong A[16];
   unsigned long a = s2[0];
   /* unsigned long b = s1[0]; */
   unsigned long u;
   _ntl_ulong hi, lo;

   A[0] = 0;
   A[1] = a;
   A[2] = A[1] << 1;
   A[3] = A[2] ^ A[1];
   A[4] = A[2] << 1;
   A[5] = A[4] ^ A[1];
   A[6] = A[3] << 1;
   A[7] = A[6] ^ A[1];
   A[8] = A[4] << 1;
   A[9] = A[8] ^ A[1];
   A[10] = A[5] << 1;
   A[11] = A[10] ^ A[1];
   A[12] = A[6] << 1;
   A[13] = A[12] ^ A[1];
   A[14] = A[7] << 1;
   A[15] = A[14] ^ A[1];

#define	t0	lo
#define	t1	hi
#if 0
   lo = (A[b >> 60] << 4) ^ A[(b >> 56) & 15];
   hi = lo >> 56;
   lo = (lo << 8) ^ (A[(b >> 52) & 15] << 4) ^ A[(b >> 48) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 44) & 15] << 4) ^ A[(b >> 40) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 36) & 15] << 4) ^ A[(b >> 32) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 28) & 15] << 4) ^ A[(b >> 24) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 20) & 15] << 4) ^ A[(b >> 16) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 12) & 15] << 4) ^ A[(b >> 8) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(b >> 4) & 15] << 4) ^ A[b & 15];
#else
                u = A[s1[0]       & 15] ^ A[s1[0] >>  4 & 15] << 4;
                t0  = u;
                u = A[s1[0] >>  8 & 15] ^ A[s1[0] >> 12 & 15] << 4; 
                t0 ^= u <<  8; t1 = u >> 56;
                u = A[s1[0] >> 16 & 15] ^ A[s1[0] >> 20 & 15] << 4;
                t0 ^= u << 16; t1 ^= u >> 48;
                u = A[s1[0] >> 24 & 15] ^ A[s1[0] >> 28 & 15] << 4;
                t0 ^= u << 24; t1 ^= u >> 40;
                u = A[s1[0] >> 32 & 15] ^ A[s1[0] >> 36 & 15] << 4;
                t0 ^= u << 32; t1 ^= u >> 32;
                u = A[s1[0] >> 40 & 15] ^ A[s1[0] >> 44 & 15] << 4;
                t0 ^= u << 40; t1 ^= u >> 24;
                u = A[s1[0] >> 48 & 15] ^ A[s1[0] >> 52 & 15] << 4;
                t0 ^= u << 48; t1 ^= u >> 16;
                u = A[s1[0] >> 56 & 15] ^ A[s1[0] >> 60 & 15] << 4;
                t0 ^= u << 56; t1 ^= u >>  8;
#endif

#if 0
   {
     _ntl_ulong tmp;
     tmp = -((a >> 63) & 1);
     tmp &= ((b & 0xfefefefefefefefe) >> 1);
     hi = hi ^ tmp;
     tmp = -((a >> 62) & 1);
     tmp &= ((b & 0xfcfcfcfcfcfcfcfc) >> 2);
     hi = hi ^ tmp;
     tmp = -((a >> 61) & 1);
     tmp &= ((b & 0xf8f8f8f8f8f8f8f8) >> 3);
     hi = hi ^ tmp;
     tmp = -((a >> 60) & 1);
     tmp &= ((b & 0xf0f0f0f0f0f0f0f0) >> 4);
     hi = hi ^ tmp;
     tmp = -((a >> 59) & 1);
     tmp &= ((b & 0xe0e0e0e0e0e0e0e0) >> 5);
     hi = hi ^ tmp;
     tmp = -((a >> 58) & 1);
     tmp &= ((b & 0xc0c0c0c0c0c0c0c0) >> 6);
     hi = hi ^ tmp;
     tmp = -((a >> 57) & 1);
     tmp &= ((b & 0x8080808080808080) >> 7);
     hi = hi ^ tmp;
   }
#endif
                u = 0x8080808080808080UL & -(s2[0] >> 57 & 1);
                t1 ^= (u & s1[0]) >> 7;
                u = 0xc0c0c0c0c0c0c0c0UL & -(s2[0] >> 58 & 1);
                t1 ^= (u & s1[0]) >> 6;
                u = 0xe0e0e0e0e0e0e0e0UL & -(s2[0] >> 59 & 1);
                t1 ^= (u & s1[0]) >> 5;
                u = 0xf0f0f0f0f0f0f0f0UL & -(s2[0] >> 60 & 1);
                t1 ^= (u & s1[0]) >> 4;
                u = 0xf8f8f8f8f8f8f8f8UL & -(s2[0] >> 61 & 1);
                t1 ^= (u & s1[0]) >> 3;
                u = 0xfcfcfcfcfcfcfcfcUL & -(s2[0] >> 62 & 1);
                t1 ^= (u & s1[0]) >> 2;
                u = 0xfefefefefefefefeUL & -(s2[0] >> 63 );
                t1 ^= (u & s1[0]) >> 1;
#undef t0
#undef t1
	t[0] $op lo;
	t[1] $op hi;
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_interleaved {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
	unsigned long g[16];
	unsigned long u;
	unsigned long t0, t1;
	unsigned long m = 0x8080808080808080UL;

	g[0] = 0;		u = m & -(s2[0] >> 57 & 1);
	g[1] = s2[0];           t1 = (u & s1[0]) >> 7;
	g[2] = g[1] << 1;	m |= m >> 1; u = m & -(s2[0] >> 58 & 1);
	g[3] = g[2] ^ g[1];     t1 ^= (u & s1[0]) >> 6;
	g[4] = g[2] << 1;	m |= m >> 1; u = m & -(s2[0] >> 59 & 1);
	g[5] = g[4] ^ g[1];     t1 ^= (u & s1[0]) >> 5;
	g[6] = g[3] << 1;	
	g[7] = g[6] ^ g[1];     
	g[8] = g[4] << 1;	m |= m >> 1; u = m & -(g[8] >> 63);
	g[9] = g[8] ^ g[1];     t1 ^= (u & s1[0]) >> 4;
	g[10] = g[5] << 1;	m |= m >> 1; u = m & -(g[4] >> 63);
	g[11] = g[10] ^ g[1];   t1 ^= (u & s1[0]) >> 3;
	g[12] = g[6] << 1;	m |= m >> 1; u = m & -(g[2] >> 63);
	g[13] = g[12] ^ g[1];   t1 ^= (u & s1[0]) >> 2;
	g[14] = g[7] << 1;      m |= m >> 1; u = m & -(s2[0] >> 63 );
	g[15] = g[14] ^ g[1];   t1 ^= (u & s1[0]) >> 1;


	u = g[s1[0]       & 15] ^ g[s1[0] >>  4 & 15] << 4;
	t0  = u;
	u = g[s1[0] >>  8 & 15] ^ g[s1[0] >> 12 & 15] << 4; 
	t0 ^= u <<  8; t1 ^= u >> 56;
	u = g[s1[0] >> 16 & 15] ^ g[s1[0] >> 20 & 15] << 4;
	t0 ^= u << 16; t1 ^= u >> 48;
	u = g[s1[0] >> 24 & 15] ^ g[s1[0] >> 28 & 15] << 4;
	t0 ^= u << 24; t1 ^= u >> 40;
	u = g[s1[0] >> 32 & 15] ^ g[s1[0] >> 36 & 15] << 4;
	t0 ^= u << 32; t1 ^= u >> 32;
	u = g[s1[0] >> 40 & 15] ^ g[s1[0] >> 44 & 15] << 4;
	t0 ^= u << 40; t1 ^= u >> 24;
	u = g[s1[0] >> 48 & 15] ^ g[s1[0] >> 52 & 15] << 4;
	t0 ^= u << 48; t1 ^= u >> 16;
	u = g[s1[0] >> 56 & 15] ^ g[s1[0] >> 60 & 15] << 4;
	t0 ^= u << 56; t1 ^= u >>  8;

	t[0] $op t0;
	t[1] $op t1;
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_interleaved_rpb {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
   _ntl_ulong hi, lo, hj;
   _ntl_ulong A[16];

   A[0] = 0;			hi =  0x8080808080808080;
   A[1] = s1[0]; 		hj =  (-((s1[0] >> 57) & 1)) & ((s2[0] & hi) >> 7); 
   A[2] = A[1] << 1;		hi |= (hi >> 1);
   A[3] = A[2] ^ A[1];		hj ^= (-((s1[0] >> 58) & 1)) & ((s2[0] & hi) >> 6); 
   A[4] = A[2] << 1;		hi |= (hi >> 1);
   A[5] = A[4] ^ A[1];		hj ^= (-((s1[0] >> 59) & 1)) & ((s2[0] & hi) >> 5); 
   A[6] = A[3] << 1;		hi |= (hi >> 1);
   A[7] = A[6] ^ A[1];		hj ^= (-((s1[0] >> 60) & 1)) & ((s2[0] & hi) >> 4); 
   A[8] = A[4] << 1;		hi |= (hi >> 1);
   A[9] = A[8] ^ A[1];		hj ^= (-((s1[0] >> 61) & 1)) & ((s2[0] & hi) >> 3); 
   A[10] = A[5] << 1;		hi |= (hi >> 1);
   A[11] = A[10] ^ A[1];	hj ^= (-((s1[0] >> 62) & 1)) & ((s2[0] & hi) >> 2); 
   A[12] = A[6] << 1;		hi |= (hi >> 1);
   A[13] = A[12] ^ A[1];	hj ^= (-((s1[0] >> 63) & 1)) & ((s2[0] & hi) >> 1);
   A[14] = A[7] << 1;
   A[15] = A[14] ^ A[1];

   lo = (A[s2[0] >> 60] << 4) ^ A[(s2[0] >> 56) & 15];
   hi = lo >> 56;
   lo = (lo << 8) ^ (A[(s2[0] >> 52) & 15] << 4) ^ A[(s2[0] >> 48) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(s2[0] >> 44) & 15] << 4) ^ A[(s2[0] >> 40) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(s2[0] >> 36) & 15] << 4) ^ A[(s2[0] >> 32) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(s2[0] >> 28) & 15] << 4) ^ A[(s2[0] >> 24) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(s2[0] >> 20) & 15] << 4) ^ A[(s2[0] >> 16) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(s2[0] >> 12) & 15] << 4) ^ A[(s2[0] >> 8) & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (A[(s2[0] >> 4) & 15] << 4) ^ A[s2[0] & 15];

   t[0] $op lo;
   t[1] $op hi^hj;
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_interleaved_r2 {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
   unsigned long hi, lo, hj;
   unsigned long g[16];
   {
   const unsigned long m = 0xfefefefefefefefeUL;
   unsigned long v,w;
   g[0] = 0;			v = s1[0];
   g[1] = s2[0]; 		w = -(s2[0] >> 63);
   g[2] = g[1] << 1;		v = (v & m) >> 1; hj = v & w;
   g[3] = g[2] ^ g[1];		w = -(g[2] >> 63);
   g[4] = g[2] << 1;		v = (v & m) >> 1; hj ^= v & w;
   g[5] = g[4] ^ g[1];		w = -(g[4] >> 63);
   g[6] = g[3] << 1;		v = (v & m) >> 1; hj ^= v & w;
   g[7] = g[6] ^ g[1];		
   g[8] = g[4] << 1;		w = -(g[8] >> 63);
   g[9] = g[8] ^ g[1];		v = (v & m) >> 1; hj ^= v & w;
   g[10] = g[5] << 1;		w = -((g[1] << 4) >> 63);
   g[11] = g[10] ^ g[1];	v = (v & m) >> 1; hj ^= v & w;
   g[12] = g[6] << 1;		w = -((g[1] << 5) >> 63);
   g[13] = g[12] ^ g[1];	v = (v & m) >> 1; hj ^= v & w;
   g[14] = g[7] << 1;           w = -((g[1] << 6) >> 63);
   g[15] = g[14] ^ g[1];        v = (v & m) >> 1; hj ^= v & w;
   }
                                

   lo = (g[s1[0] >> 60] << 4) ^ g[s1[0] >> 56 & 15];
   hi = lo >> 56;
   lo = (lo << 8) ^ (g[s1[0] >> 52 & 15] << 4) ^ g[s1[0] >> 48 & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (g[s1[0] >> 44 & 15] << 4) ^ g[s1[0] >> 40 & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (g[s1[0] >> 36 & 15] << 4) ^ g[s1[0] >> 32 & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (g[s1[0] >> 28 & 15] << 4) ^ g[s1[0] >> 24 & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (g[s1[0] >> 20 & 15] << 4) ^ g[s1[0] >> 16 & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (g[s1[0] >> 12 & 15] << 4) ^ g[s1[0] >> 8 & 15];
   hi = (hi << 8) | (lo >> 56);
   lo = (lo << 8) ^ (g[s1[0] >> 4 & 15] << 4) ^ g[s1[0] & 15];

   t[0] $op lo;
   t[1] $op hi^hj;
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_interleaved_r3 {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
	unsigned long g[16];
	unsigned long u;
	unsigned long t0, t1;
	{
	unsigned long v,w;
	const unsigned long m =  0xfefefefefefefefeUL;
	g[0] = 0;		
	g[1] = s2[0]; 		v = s1[0];
	g[2] = g[1] << 1;	w = -(s2[0] >> 63);
	g[3] = g[2] ^ g[1];	v = (v & m) >> 1; t1 = v & w;
	g[4] = g[2] << 1;	w = -(g[2] >> 63);
	g[5] = g[4] ^ g[1];	v = (v & m) >> 1; t1 ^= v & w;
	g[6] = g[3] << 1;	w = -(g[4] >> 63);
	g[7] = g[6] ^ g[1];	v = (v & m) >> 1; t1 ^= v & w;
	g[8] = g[4] << 1;	w = -(g[8] >> 63);
	g[9] = g[8] ^ g[1];	v = (v & m) >> 1; t1 ^= v & w;
	g[10] = g[5] << 1;	w = -((g[1] << 4) >> 63);
	g[11] = g[10] ^ g[1];	v = (v & m) >> 1; t1 ^= v & w;
	g[12] = g[6] << 1;	w = -((g[1] << 5) >> 63);
	g[13] = g[12] ^ g[1];	v = (v & m) >> 1; t1 ^= v & w;
	g[14] = g[7] << 1;      w = -((g[1] << 6) >> 63);
	g[15] = g[14] ^ g[1];   v = (v & m) >> 1; t1 ^= v & w;
	}


	u = g[s1[0]       & 15] ^ g[s1[0] >>  4 & 15] << 4;
	t0  = u;
	u = g[s1[0] >>  8 & 15] ^ g[s1[0] >> 12 & 15] << 4; 
	t0 ^= u <<  8; t1 ^= u >> 56;
	u = g[s1[0] >> 16 & 15] ^ g[s1[0] >> 20 & 15] << 4;
	t0 ^= u << 16; t1 ^= u >> 48;
	u = g[s1[0] >> 24 & 15] ^ g[s1[0] >> 28 & 15] << 4;
	t0 ^= u << 24; t1 ^= u >> 40;
	u = g[s1[0] >> 32 & 15] ^ g[s1[0] >> 36 & 15] << 4;
	t0 ^= u << 32; t1 ^= u >> 32;
	u = g[s1[0] >> 40 & 15] ^ g[s1[0] >> 44 & 15] << 4;
	t0 ^= u << 40; t1 ^= u >> 24;
	u = g[s1[0] >> 48 & 15] ^ g[s1[0] >> 52 & 15] << 4;
	t0 ^= u << 48; t1 ^= u >> 16;
	u = g[s1[0] >> 56 & 15] ^ g[s1[0] >> 60 & 15] << 4;
	t0 ^= u << 56; t1 ^= u >>  8;

	t[0] $op t0;
	t[1] $op t1;
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul1_interleaved_r4_slow {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
   unsigned long t0, t1;
   unsigned long g[16];
   unsigned long m;
   unsigned long u,v,w;
				m =  0xeeeeeeeeeeeeeeeeUL;
   g[0] = 0;			v = s1[0];
   g[1] = s2[0]; 		w = -(s2[0] >> 63);
   g[2] = g[1] << 1;		v = (v & m) >> 1; t1 = v & w;
   g[3] = g[2] ^ g[1];		w = -(g[2] >> 63);
   g[4] = g[2] << 1;		v = (v & m) >> 1; t1 ^= v & w;
   g[5] = g[4] ^ g[1];		w = -(g[4] >> 63);
   g[6] = g[3] << 1;		v = (v & m) >> 1; t1 ^= v & w;
   g[7] = g[6] ^ g[1];		
   g[8] = g[4] << 1;		
   g[9] = g[8] ^ g[1];		
   g[10] = g[5] << 1;		
   g[11] = g[10] ^ g[1];	
   g[12] = g[6] << 1;		
   g[13] = g[12] ^ g[1];	
   g[14] = g[7] << 1;           
   g[15] = g[14] ^ g[1];        
                                

        u = g[s1[0]       & 15]; t0  = u;
        u = g[s1[0] >>  4 & 15]; t0 ^= u <<  4; t1 ^= u >> 60;
        u = g[s1[0] >>  8 & 15]; t0 ^= u <<  8; t1 ^= u >> 56;
        u = g[s1[0] >> 12 & 15]; t0 ^= u << 12; t1 ^= u >> 52;
        u = g[s1[0] >> 16 & 15]; t0 ^= u << 16; t1 ^= u >> 48;
        u = g[s1[0] >> 20 & 15]; t0 ^= u << 20; t1 ^= u >> 44;
        u = g[s1[0] >> 24 & 15]; t0 ^= u << 24; t1 ^= u >> 40; 
        u = g[s1[0] >> 28 & 15]; t0 ^= u << 28; t1 ^= u >> 36; 
        u = g[s1[0] >> 32 & 15]; t0 ^= u << 32; t1 ^= u >> 32; 
        u = g[s1[0] >> 36 & 15]; t0 ^= u << 36; t1 ^= u >> 28; 
        u = g[s1[0] >> 40 & 15]; t0 ^= u << 40; t1 ^= u >> 24; 
        u = g[s1[0] >> 44 & 15]; t0 ^= u << 44; t1 ^= u >> 20; 
        u = g[s1[0] >> 48 & 15]; t0 ^= u << 48; t1 ^= u >> 16; 
        u = g[s1[0] >> 52 & 15]; t0 ^= u << 52; t1 ^= u >> 12; 
        u = g[s1[0] >> 56 & 15]; t0 ^= u << 56; t1 ^= u >>  8; 
        u = g[s1[0] >> 60 & 15]; t0 ^= u << 60; t1 ^= u >>  4; 

   t[0] $op t0;
   t[1] $op t1;
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul2_rpb {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
#define SHL(x, r) _mm_slli_epi64((x), (r))
#define SHR(x, r) _mm_srli_epi64((x), (r))
#define SHLD(x, r) _mm_slli_si128((x), (r) >> 3)
#define SHRD(x, r) _mm_srli_si128((x), (r) >> 3)
	__v2di u;
	__v2di t0;
	__v2di t1;
	__v2di t2;

	__v2di g[16];			//	__v2di b0 = *(__v2di*)s2;
        __v2di b0 = (__v2di) {s2[0], s2[1]};
	__v2di b1 = SHL(b0, 1);
	__v2di b2 = SHL(b0, 2);
	__v2di b3 = SHL(b0, 3);
	__v2di y = (__v2di) { 0, 0, };
	__v2di v1 = (__v2di) { s1[0], s1[0], };
	__v2di v2 = (__v2di) { s1[1], s1[1], };
	__v2di w;
	__v16qi m;

	/* repair steps and building table interleaved */

	m = ~ (__v16qi) (__v2di) { 0,0 };
	g[ 0] = y; y  = b0;
	g[ 1] = y; y ^= b1;
	m = m + m;
	w = (__v2di) m & -SHR(b0,63);
	t1 = SHR(v1 & w, 1);
	t2 = SHR(v2 & w, 1);
	g[ 3] = y; y  = b1;
	g[ 2] = y; y ^= b2;
	m = m + m;
	w = (__v2di) m & -SHR(b1,63);
	t1 ^= SHR(v1 & w, 2);
	t2 ^= SHR(v2 & w, 2);
	g[ 6] = y; y ^= b0;
	g[ 7] = y; y ^= b1;
	m = m + m;
	w = (__v2di) m & -SHR(b2,63);
	t1 ^= SHR(v1 & w, 3);
	t2 ^= SHR(v2 & w, 3);
	g[ 5] = y; y  = b2;
	g[ 4] = y; y ^= b3;
	m = m + m;
	w = (__v2di) m & -SHR(b3,63);
	t1 ^= SHR(v1 & w, 4);
	t2 ^= SHR(v2 & w, 4);
	g[12] = y; y ^= b0;
	g[13] = y; y ^= b1;
	m = m + m;
	w = (__v2di) m & -SHR(SHL(b0, 4),63);
	t1 ^= SHR(v1 & w, 5);
	t2 ^= SHR(v2 & w, 5);
	g[15] = y; y ^= b0;
	g[14] = y; y ^= b2;
	m = m + m;
	w = (__v2di) m & -SHR(SHL(b0, 5),63);
	t1 ^= SHR(v1 & w, 6);
	t2 ^= SHR(v2 & w, 6);
	g[10] = y; y ^= b0;
	g[11] = y; y ^= b1;
	m = m + m;
	w = (__v2di) m & -SHR(SHL(b0, 6),63);
	t1 ^= SHR(v1 & w, 7);
	t2 ^= SHR(v2 & w, 7);
	g[ 9] = y; y  = b3;
	g[ 8] = y;
	
	/* round 0 */
	
	u = g[s1[0]       & 15]
	  ^ SHL(g[s1[0] >>  4 & 15], 4);
	t0  = u;
	u = g[s1[0] >>  8 & 15]
	  ^ SHL(g[s1[0] >> 12 & 15], 4);
	t0 ^= SHL(u,  8); t1 ^= SHR(u, 56);
	u = g[s1[0] >> 16 & 15]
	  ^ SHL(g[s1[0] >> 20 & 15], 4);
	t0 ^= SHL(u, 16); t1 ^= SHR(u, 48);
	u = g[s1[0] >> 24 & 15]
	  ^ SHL(g[s1[0] >> 28 & 15], 4);
	t0 ^= SHL(u, 24); t1 ^= SHR(u, 40);
	u = g[s1[0] >> 32 & 15]
	  ^ SHL(g[s1[0] >> 36 & 15], 4);
	t0 ^= SHL(u, 32); t1 ^= SHR(u, 32);
	u = g[s1[0] >> 40 & 15]
	  ^ SHL(g[s1[0] >> 44 & 15], 4);
	t0 ^= SHL(u, 40); t1 ^= SHR(u, 24);
	u = g[s1[0] >> 48 & 15]
	  ^ SHL(g[s1[0] >> 52 & 15], 4);
	t0 ^= SHL(u, 48); t1 ^= SHR(u, 16);
	u = g[s1[0] >> 56 & 15]
	  ^ SHL(g[s1[0] >> 60 & 15], 4);
	t0 ^= SHL(u, 56); t1 ^= SHR(u,  8);
	
	/* round 1 */
	
	u = g[s1[1]       & 15]
	  ^ SHL(g[s1[1] >>  4 & 15], 4);
	t1 ^= u;
	u = g[s1[1] >>  8 & 15]
	  ^ SHL(g[s1[1] >> 12 & 15], 4);
	t1 ^= SHL(u,  8); t2 ^= SHR(u, 56);
	u = g[s1[1] >> 16 & 15]
	  ^ SHL(g[s1[1] >> 20 & 15], 4);
	t1 ^= SHL(u, 16); t2 ^= SHR(u, 48);
	u = g[s1[1] >> 24 & 15]
	  ^ SHL(g[s1[1] >> 28 & 15], 4);
	t1 ^= SHL(u, 24); t2 ^= SHR(u, 40);
	u = g[s1[1] >> 32 & 15]
	  ^ SHL(g[s1[1] >> 36 & 15], 4);
	t1 ^= SHL(u, 32); t2 ^= SHR(u, 32);
	u = g[s1[1] >> 40 & 15]
	  ^ SHL(g[s1[1] >> 44 & 15], 4);
	t1 ^= SHL(u, 40); t2 ^= SHR(u, 24);
	u = g[s1[1] >> 48 & 15]
	  ^ SHL(g[s1[1] >> 52 & 15], 4);
	t1 ^= SHL(u, 48); t2 ^= SHR(u, 16);
	u = g[s1[1] >> 56 & 15]
	  ^ SHL(g[s1[1] >> 60 & 15], 4);
	t1 ^= SHL(u, 56); t2 ^= SHR(u,  8);
	/* end */
	
	/* store result */
	
	typedef union { __v2di s; unsigned long x[2]; } v2di_proxy;
        {
                v2di_proxy r;
                r.s = t0 ^ SHLD(t1, 64); 
                t[0] $op r.x[0];
                t[1] $op r.x[1];
        }

        { 
                v2di_proxy r;
                r.s = t2 ^ SHRD(t1, 64);
                t[2] $op r.x[0];
                t[3] $op r.x[1];
        } 
#undef SHL
#undef SHR
#undef SHLD
#undef SHRD
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul2_rpb2 {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
#define SHL(x, r) _mm_slli_epi64((x), (r))
#define SHR(x, r) _mm_srli_epi64((x), (r))
#define SHLD(x, r) _mm_slli_si128((x), (r) >> 3)
#define SHRD(x, r) _mm_srli_si128((x), (r) >> 3)
	__v2di u;
	__v2di t0;
	__v2di t1;
	__v2di t2;

	__v2di g[16];			//	__v2di b0 = *(__v2di*)s2;
        __v2di b0 = (__v2di) {s2[0], s2[1]};
	__v2di b1 = SHL(b0, 1);
	__v2di b2 = SHL(b0, 2);
	__v2di b3 = SHL(b0, 3);
	__v2di y = (__v2di) { 0, 0, };
	__v2di v1 = (__v2di) { s1[0], s1[0], };
	__v2di v2 = (__v2di) { s1[1], s1[1], };
	__v2di w;

	/* repair steps and building table interleaved */

	__v2di m = (__v2di) { 0xfefefefefefefefeUL, 0xfefefefefefefefeUL, };
	g[ 0] = y; y  = b0;
	g[ 1] = y; y ^= b1;
        w = -SHR(b0,63);
        v1 = SHR(v1 & m, 1);
        t1 = v1 & w;
        v2 = SHR(v2 & m, 1);
        t2 = v2 & w;
	g[ 3] = y; y  = b1;
	g[ 2] = y; y ^= b2;
        w = -SHR(b1,63);
        v1 = SHR(v1 & m, 1);
        t1 ^= v1 & w;
        v2 = SHR(v2 & m, 1);
        t2 ^= v2 & w;
	g[ 6] = y; y ^= b0;
	g[ 7] = y; y ^= b1;
        w = -SHR(b2,63);
        v1 = SHR(v1 & m, 1);
        t1 ^= v1 & w;
        v2 = SHR(v2 & m, 1);
        t2 ^= v2 & w;
	g[ 5] = y; y  = b2;
	g[ 4] = y; y ^= b3;
        w = -SHR(b3,63);
        v1 = SHR(v1 & m, 1);
        t1 ^= v1 & w;
        v2 = SHR(v2 & m, 1);
        t2 ^= v2 & w;
	g[12] = y; y ^= b0;
	g[13] = y; y ^= b1;
        w = -SHR(SHL(b0, 4),63);
        v1 = SHR(v1 & m, 1);
        t1 ^= v1 & w;
        v2 = SHR(v2 & m, 1);
        t2 ^= v2 & w;
	g[15] = y; y ^= b0;
	g[14] = y; y ^= b2;
        w = -SHR(SHL(b0, 5),63);
        v1 = SHR(v1 & m, 1);
        t1 ^= v1 & w;
        v2 = SHR(v2 & m, 1);
        t2 ^= v2 & w;
	g[10] = y; y ^= b0;
	g[11] = y; y ^= b1;
        w = -SHR(SHL(b0, 6),63);
        v1 = SHR(v1 & m, 1);
        t1 ^= v1 & w;
        v2 = SHR(v2 & m, 1);
        t2 ^= v2 & w;
	g[ 9] = y; y  = b3;
	g[ 8] = y;
	
	/* round 0 */
	
	u = g[s1[0]       & 15]
	  ^ SHL(g[s1[0] >>  4 & 15], 4);
	t0  = u;
	u = g[s1[0] >>  8 & 15]
	  ^ SHL(g[s1[0] >> 12 & 15], 4);
	t0 ^= SHL(u,  8); t1 ^= SHR(u, 56);
	u = g[s1[0] >> 16 & 15]
	  ^ SHL(g[s1[0] >> 20 & 15], 4);
	t0 ^= SHL(u, 16); t1 ^= SHR(u, 48);
	u = g[s1[0] >> 24 & 15]
	  ^ SHL(g[s1[0] >> 28 & 15], 4);
	t0 ^= SHL(u, 24); t1 ^= SHR(u, 40);
	u = g[s1[0] >> 32 & 15]
	  ^ SHL(g[s1[0] >> 36 & 15], 4);
	t0 ^= SHL(u, 32); t1 ^= SHR(u, 32);
	u = g[s1[0] >> 40 & 15]
	  ^ SHL(g[s1[0] >> 44 & 15], 4);
	t0 ^= SHL(u, 40); t1 ^= SHR(u, 24);
	u = g[s1[0] >> 48 & 15]
	  ^ SHL(g[s1[0] >> 52 & 15], 4);
	t0 ^= SHL(u, 48); t1 ^= SHR(u, 16);
	u = g[s1[0] >> 56 & 15]
	  ^ SHL(g[s1[0] >> 60 & 15], 4);
	t0 ^= SHL(u, 56); t1 ^= SHR(u,  8);
	
	/* round 1 */
	
	u = g[s1[1]       & 15]
	  ^ SHL(g[s1[1] >>  4 & 15], 4);
	t1 ^= u;
	u = g[s1[1] >>  8 & 15]
	  ^ SHL(g[s1[1] >> 12 & 15], 4);
	t1 ^= SHL(u,  8); t2 ^= SHR(u, 56);
	u = g[s1[1] >> 16 & 15]
	  ^ SHL(g[s1[1] >> 20 & 15], 4);
	t1 ^= SHL(u, 16); t2 ^= SHR(u, 48);
	u = g[s1[1] >> 24 & 15]
	  ^ SHL(g[s1[1] >> 28 & 15], 4);
	t1 ^= SHL(u, 24); t2 ^= SHR(u, 40);
	u = g[s1[1] >> 32 & 15]
	  ^ SHL(g[s1[1] >> 36 & 15], 4);
	t1 ^= SHL(u, 32); t2 ^= SHR(u, 32);
	u = g[s1[1] >> 40 & 15]
	  ^ SHL(g[s1[1] >> 44 & 15], 4);
	t1 ^= SHL(u, 40); t2 ^= SHR(u, 24);
	u = g[s1[1] >> 48 & 15]
	  ^ SHL(g[s1[1] >> 52 & 15], 4);
	t1 ^= SHL(u, 48); t2 ^= SHR(u, 16);
	u = g[s1[1] >> 56 & 15]
	  ^ SHL(g[s1[1] >> 60 & 15], 4);
	t1 ^= SHL(u, 56); t2 ^= SHR(u,  8);
	/* end */
	
	/* store result */
	
	typedef union { __v2di s; unsigned long x[2]; } v2di_proxy;
        {
                v2di_proxy r;
                r.s = t0 ^ SHLD(t1, 64); 
                t[0] $op r.x[0];
                t[1] $op r.x[1];
        }

        { 
                v2di_proxy r;
                r.s = t2 ^ SHRD(t1, 64);
                t[2] $op r.x[0];
                t[3] $op r.x[1];
        } 
#undef SHL
#undef SHR
#undef SHLD
#undef SHRD
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}
sub code_for_mul2_interleave3 {#{{{
    my ($opt)=@_;
    my $op = $opt->{'add'} ? '^=' : '=';
    my $code = <<EOF;
typedef union { __v2di s; unsigned long x[2]; } v2di_proxy;
#define SHL(x, r) _mm_slli_epi64((x), (r))
#define SHR(x, r) _mm_srli_epi64((x), (r))
#define SHLD(x, r) _mm_slli_si128((x), (r) >> 3)
#define SHRD(x, r) _mm_srli_si128((x), (r) >> 3)
__v2di u;
__v2di t0;
__v2di t1;
__v2di t2;

__v2di g[16];
__v2di w;
__v2di m = (__v2di) { 0xeeeeeeeeeeeeeeeeUL, 0xeeeeeeeeeeeeeeeeUL, };
/* sequence update walk */
g[ 0] = (__v2di) { 0, };
__v2di b0 = (__v2di) { s2[0], s2[1], };
g[ 1] = b0;
__v2di v1 = (__v2di) { s1[0], s1[0], };
w = -SHR(b0,63);
__v2di v2 = (__v2di) { s1[1], s1[1], };
v1 = SHR(v1 & m, 1); t1 = v1 & w;
g[ 2] = SHL(b0, 1); g[ 3] = g[ 2] ^ b0;
v2 = SHR(v2 & m, 1); t2 = v2 & w;
g[ 4] = SHL(g[ 2], 1); g[ 5] = g[ 4] ^ b0;
w = -SHR(g[ 2],63);
g[ 6] = SHL(g[ 3], 1); g[ 7] = g[ 6] ^ b0;
v1 = SHR(v1 & m, 1); t1 ^= v1 & w;
g[ 8] = SHL(g[ 4], 1); g[ 9] = g[ 8] ^ b0;
v2 = SHR(v2 & m, 1); t2 ^= v2 & w;
g[10] = SHL(g[ 5], 1); g[11] = g[10] ^ b0;
w = -SHR(g[4],63);
g[12] = SHL(g[ 6], 1); g[13] = g[12] ^ b0;
v1 = SHR(v1 & m, 1); t1 ^= v1 & w;
g[14] = SHL(g[ 7], 1); g[15] = g[14] ^ b0;
v2 = SHR(v2 & m, 1); t2 ^= v2 & w;



/* round 0 */
u = g[s1[0]       & 15]; t0  = u;
u = g[s1[0] >>  4 & 15]; t0 ^= SHL(u,  4); t1 ^= SHR(u, 60);
u = g[s1[0] >>  8 & 15]; t0 ^= SHL(u,  8); t1 ^= SHR(u, 56);
u = g[s1[0] >> 12 & 15]; t0 ^= SHL(u, 12); t1 ^= SHR(u, 52);
u = g[s1[0] >> 16 & 15]; t0 ^= SHL(u, 16); t1 ^= SHR(u, 48);
u = g[s1[0] >> 20 & 15]; t0 ^= SHL(u, 20); t1 ^= SHR(u, 44);
u = g[s1[0] >> 24 & 15]; t0 ^= SHL(u, 24); t1 ^= SHR(u, 40);
u = g[s1[0] >> 28 & 15]; t0 ^= SHL(u, 28); t1 ^= SHR(u, 36);
u = g[s1[0] >> 32 & 15]; t0 ^= SHL(u, 32); t1 ^= SHR(u, 32);
u = g[s1[0] >> 36 & 15]; t0 ^= SHL(u, 36); t1 ^= SHR(u, 28);
u = g[s1[0] >> 40 & 15]; t0 ^= SHL(u, 40); t1 ^= SHR(u, 24);
u = g[s1[0] >> 44 & 15]; t0 ^= SHL(u, 44); t1 ^= SHR(u, 20);
u = g[s1[0] >> 48 & 15]; t0 ^= SHL(u, 48); t1 ^= SHR(u, 16);
u = g[s1[0] >> 52 & 15]; t0 ^= SHL(u, 52); t1 ^= SHR(u, 12);
u = g[s1[0] >> 56 & 15]; t0 ^= SHL(u, 56); t1 ^= SHR(u,  8);
u = g[s1[0] >> 60 & 15]; t0 ^= SHL(u, 60); t1 ^= SHR(u,  4);

/* round 1 */
u = g[s1[1]       & 15]; t1 ^= u;
u = g[s1[1] >>  4 & 15]; t1 ^= SHL(u,  4); t2 ^= SHR(u, 60);
u = g[s1[1] >>  8 & 15]; t1 ^= SHL(u,  8); t2 ^= SHR(u, 56);
u = g[s1[1] >> 12 & 15]; t1 ^= SHL(u, 12); t2 ^= SHR(u, 52);
u = g[s1[1] >> 16 & 15]; t1 ^= SHL(u, 16); t2 ^= SHR(u, 48);
u = g[s1[1] >> 20 & 15]; t1 ^= SHL(u, 20); t2 ^= SHR(u, 44);
u = g[s1[1] >> 24 & 15]; t1 ^= SHL(u, 24); t2 ^= SHR(u, 40);
u = g[s1[1] >> 28 & 15]; t1 ^= SHL(u, 28); t2 ^= SHR(u, 36);
u = g[s1[1] >> 32 & 15]; t1 ^= SHL(u, 32); t2 ^= SHR(u, 32);
u = g[s1[1] >> 36 & 15]; t1 ^= SHL(u, 36); t2 ^= SHR(u, 28);
u = g[s1[1] >> 40 & 15]; t1 ^= SHL(u, 40); t2 ^= SHR(u, 24);
u = g[s1[1] >> 44 & 15]; t1 ^= SHL(u, 44); t2 ^= SHR(u, 20);
u = g[s1[1] >> 48 & 15]; t1 ^= SHL(u, 48); t2 ^= SHR(u, 16);
u = g[s1[1] >> 52 & 15]; t1 ^= SHL(u, 52); t2 ^= SHR(u, 12);
u = g[s1[1] >> 56 & 15]; t1 ^= SHL(u, 56); t2 ^= SHR(u,  8);
u = g[s1[1] >> 60 & 15]; t1 ^= SHL(u, 60); t2 ^= SHR(u,  4);
/* end */

/* store result */
{
	v2di_proxy r;
	r.s = t0 ^ SHLD(t1, 64);
	t[0] $op r.x[0];
	t[1] $op r.x[1];
}

{
	v2di_proxy r;
	r.s = t2 ^ SHRD(t1, 64);
	t[2] $op r.x[0];
	t[3] $op r.x[1];
}
#undef SHL
#undef SHR
#undef SHLD
#undef SHRD
EOF
    $code =~ s/_ntl_ulong/unsigned long/g;
    $code =~ s/ulong/unsigned long/g;
    return [ 'inline(t,s1,s2)', $code ];
}#}}}

# Get all routines above, and give all of them as alternatives.
sub alternatives {
    my $opt = shift @_;
    return if $opt->{'w'} != 64;
    return if $opt->{'e1'} != $opt->{'e2'};
    return if $opt->{'e1'} != 64 && $opt->{'e1'} != 128;

    my $h = symbol_table_of(__PACKAGE__);

    my @x = ();

    for my $k (keys %$h) {
        next unless $k =~ /^code_for/;

        next if $k =~ /^code_for_mul1/ && $opt->{'e1'} != 64;
        next if $k =~ /^code_for_mul2/ && $opt->{'e1'} != 128;

        my %option_hash = %$opt;
        push @x, [ "$opt->{'e1'}x$opt->{'e2'} $h->{$k}", \&{$h->{$k}}, \%option_hash ];
    }

    return @x;
}

sub requirements { return { includes=>'<emmintrin.h>' }; }

push @Mpfq::gf2x::details_packages, __PACKAGE__;

my $h = symbol_table_of(__PACKAGE__);
for my $k (keys %$h) {
    next unless $k =~ /^code_for/;
    $Mpfq::gf2x::gf2x::details_bindings->{'*' . __PACKAGE__ . "::$k"} = \&{$h->{$k}};
}

1;
