package PerlIO::via::TimeoutWithReset;

use strict;
use warnings;

use Errno qw(ECONNRESET ETIMEDOUT);
use base qw(PerlIO::via::Timeout);

sub READ {
    # params: SELF, BUF, LEN, FH
    my $prop = $_[0]->_fh2prop($_[3]);
    $prop->{_invalid}
      # There is a bug in PerlIO::via (possibly in PerlIO ?). We would like
      # to return -1 to signify error, but doing so doesn't work (it usually
      # segfault), it looks like the implementation is not complete. So we
      # return 0.
      and $! = ECONNRESET, return 0;
    my $rv = shift->SUPER::READ(@_);
    ($rv || 0) <= 0 && 0+$! == ETIMEDOUT
      and $prop->{_invalid} = 1;
    return $rv;
}

sub WRITE {
    # params: SELF, BUF, FH
    my $prop = $_[0]->_fh2prop($_[2]);
    $prop->{_invalid}
      and $! = ECONNRESET, return -1;
    my $rv = shift->SUPER::WRITE(@_);
    ($rv || 0) <= 0 && 0+$! == ETIMEDOUT
      and $prop->{_invalid} = 1;
    return $rv;
}

1;
