BEGIN {
    use Config;
    if ( $Config{osname} eq 'MSWin32' ) {
        require Test::More;
        Test::More::plan( skip_all =>
              'should not test IO::Socket::Timeout::Strategy::Alarm under Win32' );
    }
}

use Test::More tests => 3;
use FindBin qw($Bin);
use lib "$Bin/tlib";
use TestTimeout qw(test_timeout test_normal_wait);
use Test::Exception;
use Test::MockModule;

test_timeout('Alarm');
#test_normal_wait('Alarm');

