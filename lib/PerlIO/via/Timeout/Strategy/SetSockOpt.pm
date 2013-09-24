package PerlIO::via::Timeout::Strategy::SetSockOpt;

# ABSTRACT: a L<PerlIO::via::Timeout::Strategy>, the uses setsockopt

require 5.008;
use strict;
use warnings;
use Carp;
use Errno qw(ETIMEDOUT ECONNRESET EAGAIN EWOULDBLOCK);
use Socket;

use parent qw(PerlIO::via::Timeout::Strategy::NoTimeout);

=head1 DESCRIPTION

This class implements a timeout strategy to be used by L<PerlIO::via::Timeout>.
It will work only on sockets, as it uses C<setsockopt>.

=head1 SYNOPSIS

  my $strategy = PerlIO::via::Timeout::Strategy::SetSockOpt->new(
      read_timeout => 1,
      write_timeout => 2,
  );

=cut

=method new

Constructor of the strategy. Takes as arguments a list of key / values :

=over

=item read_timeout

The read timeout in second. Can be a float

=item write_timeout

The write timeout in second. Can be a float

=item timeout_enabled

Boolean. Defaults to 1

=back

=cut

sub new {
    $^O =~ /^netbsd|solaris$/
      and croak "This Strategy is not supported on '$^O'";
    my $self = shift->SUPER::new(@_);
    open(my $fh, "<&=", $self->{_fd})
      or croak "couldn't open a new filehandle on the same file descriptor '" . $self->{_fd};
    $self->{_fh} = $fh;
    $self->_set_sock_opt();
    return $self;
}

sub read_timeout {
    my $self = shift;
    my $rv = $self->SUPER::read_timeout(@_);
    @_ and $self->_set_sock_opt();
    return $rv;
}

sub write_timeout {
    my $self = shift;
    my $rv = $self->SUPER::write_timeout(@_);
    @_ and $self->_set_sock_opt();
    $rv;
}

sub timeout_enabled {
    my $self = shift;
    my $rv = $self->SUPER::timeout_enabled(@_);
    @_ and $self->_set_sock_opt();
    $rv;
}

sub _set_sock_opt {
    my ($self) = @_;

    if ($self->timeout_enabled) {
        if (my $timeout_read = $self->{read_timeout}) {
            my $seconds  = int( $timeout_read );
            my $useconds = int( 1_000_000 * ( $timeout_read - $seconds ) );
            my $timeout  = pack( 'l!l!', $seconds, $useconds );
            setsockopt($self->{_fh}, SOL_SOCKET, SO_RCVTIMEO, $timeout )
              or croak "setsockopt(SO_RCVTIMEO): $!";
        }

        if (my $timeout_write = $self->{write_timeout}) {
            my $seconds  = int( $timeout_write );
            my $useconds = int( 1_000_000 * ( $timeout_write - $seconds ) );
            my $timeout  = pack( 'l!l!', $seconds, $useconds );

            setsockopt($self->{_fh}, SOL_SOCKET, SO_SNDTIMEO, $timeout )
              or croak "setsockopt(SO_SNDTIMEO): $!";
        }
    } else {
            setsockopt($self->{_fh}, SOL_SOCKET, SO_RCVTIMEO, 0 )
              or croak "setsockopt(SO_RCVTIMEO): $!";
            setsockopt($self->{_fh}, SOL_SOCKET, SO_SNDTIMEO, 0 )
              or croak "setsockopt(SO_SNDTIMEO): $!";
    }
}

sub READ {
    my ($self, undef, undef, $fh) = @_;

    $self->{_is_invalid}
      and $! = ECONNRESET, return 0;

    $self->timeout_enabled
      or return shift->SUPER::READ(@_);

    my $rv = shift->SUPER::READ(@_);
    if ( ($rv || 0) <= 0) {
        0+$! == EAGAIN || 0+$! == EWOULDBLOCK
          and $! = ETIMEDOUT;
        0+$! == ETIMEDOUT
          and $self->{_is_invalid} = 1;
        return 0;
    }
    return $rv;
}

sub WRITE {
    my ($self, undef, $fh, $fd) = @_;

    $self->{_is_invalid}
      and $! = ECONNRESET, return -1;

    $self->timeout_enabled
      or return shift->SUPER::WRITE(@_);

    my $rv = shift->SUPER::WRITE(@_);
    if ( ($rv || 0) <= 0) {
        0+$! == EAGAIN || 0+$! == EWOULDBLOCK
          and $! = ETIMEDOUT;
        0+$! == ETIMEDOUT
          and $self->{_is_invalid} = 1;
        return -1;
    }
    return $rv;
}

=method is_valid

  $strategy->is_valid()

Returns wether the socket from the strategy is still valid.

=cut

sub is_valid { $_[0] && ! $_[0]->{_is_invalid} }

=head1 SEE ALSO

=over

=item L<PerlIO::via::Timeout>

=back

=cut

1;
