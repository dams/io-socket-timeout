use strict;
use warnings;

BEGIN {
    if ( $^O eq 'MSWin32' ) {
        require Test::More;
        Test::More::plan( skip_all =>
              'should not test IO::Socket::Timeout::Strategy::Alarm under Win32' );
    }
}

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/tlib";
use TestTimeout;

use PerlIO::via::Timeout qw(timeout_strategy);
use Errno qw(ETIMEDOUT);


subtest 'test with no delays and no timeouts', sub {
TestTimeout->test( provider => 'AlarmWithReset',
                   connection_delay => 0,
                   read_delay => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $response = $client->getline;
                       is $response, "SOK\n", "got proper response 1";
                       $client->print("OK2\n");
                       $response = $client->getline;
                       is $response, "SOK2\n", "got proper response 2";
                   },
                 );
};

subtest 'test with read timeout', sub {
TestTimeout->test( provider => 'AlarmWithReset',
                   connection_delay => 0,
                   read_timeout => 0.2,
                   read_delay => 3,
                   write_timeout => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $response = $client->getline;
                       is $response, "SOK\n", "got proper response 1";
                       $client->print("OK2\n");
                       ok timeout_strategy($client)->is_valid, "socket is valid";
                       $response = $client->getline;
                       is $response, undef, "we've hit timeout";
                       is 0+$!, ETIMEDOUT, "and error is timeout";
                       ok ! timeout_strategy($client)->is_valid, "socket is not valid anymore";
                   },
                 );
};

done_testing;

