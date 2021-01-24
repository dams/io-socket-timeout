use strict;
use warnings;
# Test that we can syswrite and sysread to bareword filehandles

use Test::More;
use IO::Socket::Timeout;

open OUT, '>', 't/testdata.txt';
syswrite(OUT, 'This is a test file.');
close OUT;

open IN, '<', 't/testdata.txt';

my $buf;
sysread(IN, $buf, 1024);
close IN;

is($buf, 'This is a test file.');

done_testing;