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


# subtest 'test with no delays and no timeouts', sub {
# TestTimeout->test( provider => 'Alarm',
#                    connection_delay => 0,
#                    read_delay => 0,
#                    write_delay => 0,
#                    callback => sub {
#                        my ($client) = @_;
#                        print STDERR " ------ CLIENT SENDS OK\n";
#                        lives_ok {
#                            $client->print("OK\n");
#                            my $response = <$client>;
#                            print STDERR " ------ CLIENT GOT $response\n";
#                        } 'no exception while connecting, writing, reading';

# #                       throws_ok {  } qr/Error in 'ping' : $etimeout/,
# #                         "using provider $provider_name, should die in case of timeout";
# #                       throws_ok { $client->syswrite("ping") }
# #                         qr/Error in 'ping' : $ereset/,
# #                           "using provider $provider_name, should close the connection";
#                    },
#                  );
# };

subtest 'test with connection timeout', sub {
TestTimeout->test( provider => 'Alarm',
                   connection_delay => 0,
                   read_timeout => 1,
                   read_delay => 0,
                   write_delay => 0,
                   callback => sub {
                       my ($client) = @_;
                       print STDERR " ------ CLIENT SENDS OK\n";
                       lives_ok {
#                           $DB::single = 1;
                           $client->print("OK\n");
                       print STDERR " ------ done\n";
                           print STDERR " ------ CLIENT ask for response\n";
                           my $response = $client->getline;
                           print STDERR " ------ CLIENT GOT $response\n";
                       } 'no exception while connecting, writing, reading';

#                       throws_ok {  } qr/Error in 'ping' : $etimeout/,
#                         "using provider $provider_name, should die in case of timeout";
#                       throws_ok { $client->syswrite("ping") }
#                         qr/Error in 'ping' : $ereset/,
#                           "using provider $provider_name, should close the connection";
                   },
                 );
};


# TestTimeout->test( provider => 'Alarm',
#                    connection_delay => 10,
#                    connection_timeout => 1,
#                    read_delay => 0,
#                    write_delay => 0,
#                    callback => sub {
#                        my ($client) = @_;
#                        print STDERR " ------ CLIENT SENDS OK\n";
#                        print $client "OK\n";
#                        my $response = <$client>;
#                        print STDERR " ------ CLIENT GOT $response\n";
#                        pass;

# #                       throws_ok {  } qr/Error in 'ping' : $etimeout/,
# #                         "using provider $provider_name, should die in case of timeout";
# #                       throws_ok { $client->syswrite("ping") }
# #                         qr/Error in 'ping' : $ereset/,
# #                           "using provider $provider_name, should close the connection";
#                    },
#                  );
#test_normal_wait('Alarm');

done_testing;

