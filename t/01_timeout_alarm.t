use strict;
use warnings;

BEGIN {
    use Config;
    if ( $Config{osname} eq 'MSWin32' ) {
        require Test::More;
        Test::More::plan( skip_all =>
              'should not test IO::Socket::Timeout::Strategy::Alarm under Win32' );
    }
}

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/tlib";
use TestTimeout;
use Test::Exception;


subtest 'test with no delays and no timeouts', sub {
TestTimeout->test( provider => 'Alarm',
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

use POSIX qw(ETIMEDOUT ECONNRESET);

subtest 'test with read timeout', sub {
TestTimeout->test( provider => 'Alarm',
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
                       $response = $client->getline;
                       is $response, undef, "we've hit timeout";
                       is $!, 'Operation timed out', "and error is timeout";
                   },
                 );
};

subtest 'test with sysread timeout', sub {
TestTimeout->test( provider => 'Alarm',
                   connection_delay => 0,
                   read_timeout => 0.2,
                   read_delay => 3,
                   write_timeout => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       $client->print("OK\n");
                       my $buffer;
                       my $response = $client->sysread($buffer, 2);
                       is $response, 2, "got success";
                       is $buffer, "SO", "got proper response 1";
                       $client->print("OK2\n");
                       $response = $client->sysread($buffer, 1);
#                       is $response, undef, "we've hit timeout";
                       is $!, 'Operation timed out', "and error is timeout";
                   },
                 );
};

# subtest 'test with write timeout', sub {
# TestTimeout->test( provider => 'Alarm',
#                    connection_delay => 0,
#                    read_timeout => 0,
#                    read_delay => 0,
#                    write_timeout => 1,
#                    write_delay => 3,
#                    callback => sub {
#                        my ($client) = @_;
#                        print STDERR " ------ CLIENT SENDS OK\n";
#                        $client->print("OK\n");
#                        my $response = $client->getline;
#                        is $response, "SOK\n", "got proper response 1";
#                        sleep(1);
#                        my $response = $client->print("OK2\n");
#                        is $response, "SOK2\n", "got proper response 2";

# #                       is $res, undef, "we've hit timeout";
# #                       is $!, 'Operation timed out', "and error is timeout";
#                    },
#                  );
# };

done_testing;

