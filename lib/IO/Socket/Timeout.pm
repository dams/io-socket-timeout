package IO::Socket::Timeout;

use strict;
use warnings;
use Config;
use Carp;


# ABSTRACT: IO::Socket with read/write timeout

=head1 DESCRIPTION

C<IO::Socket> provides a way to set a timeout on the socket, but the timeout
will be used only for connection, not for reading / writing operations.

This module provides a way to set a timeout on read / write operations on an
C<IO::Socket> instance, or any C<IO::Socket::*> modules, like
C<IO::Socket::INET>.

=head1 SYNOPSIS

  use IO::Socket::With::Timeout;

  # creates a IO::Socket::INET::With::Timeout object
  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     # other standard arguments );

  my $socket = IO::Socket::UNIX->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     WriteTimeout => 0.5,
                                                     # other standard arguments );

  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadWriteTimeout => 0.5,
                                                     # other standard arguments );

  # When using the socket:
  use Errno qw(ETIMEDOUT EWOULDBLOCK);
  print $socket $request;
  my $response = <$socket>;
  if (! $response && ( 0+$! == ETIMEDOUT || 0+$! == EWOULDBLOCK )) {
    die "timeout reading on the socket";
  }

=head1 CONSTRUCTORS

=head2 new::with::timeout

To be able to work with any class that is or inherits from IO::Socket, the
interface of this module is a bit unusual.

C<IO::Socket::INET->new::with::timeout(...)> will return an instance of
C<IO::Socket::INET>, as if it had been called with
C<IO::Socket::INET->new(...)>. However, it'll apply some mechanism on the
resulting socket object so that it times out on read, write, or both.

The way the socket will timeout ( on connection, read, write, how long), can be
specified with these parameters:

=over

=item Timeout

This is the default parameter that already exists in IO::Socket. If set to a
value, the socket will timeout at B<connection time>.

=item ReadTimeout

If set to a value, the socket will timeout on reads. Value is in seconds, floats
accepted.

=item WriteTimeout

If set to a value, the socket will timeout on writes. Value is in seconds, floats
accepted.

=item ReadWriteTimeout

If set to a value, the socket will timeout on reads and writes. Value is in seconds, floats
accepted. If set, this option superseeds ReadTimeout and WriteTimeout.

=back

=head2 socketpair::with::timeout

There is an other way to create sockets from scratch, via C<socketpair>. As for
the C<new> constructor, this module provides its counterpart with timeout
feature.

C<IO::Socket::INET->socketpair::with::timeout(...)> will return two instances of
C<IO::Socket::INET>, as if it had been called with
C<IO::Socket::INET->socketpair(...)>. However, it'll apply some mechanism on the
resulting socket object so that it times out on read, write, or both.

=head1 METHODS

=head2 read_timeout

  my $current_timeout = $socket->read_timeout();
  $socket->read_timeout($new_timeout);

Get or set the read timeout value for a socket created with this module.

=head2 write_timeout

  my $current_timeout = $socket->write_timeout();
  $socket->write_timeout($new_timeout);

Get or set the write timeout value for a socket created with this module.

=head2 disable_timeout

  $socket->disable_timeout;

Disable the read and write timeouts for a socket created with this module.

=head2 enable_timeout

  $socket->enable_timeout;

Re-enable the read and write timeouts for a socket created with this module.

=head2 timeout_enabled

  my $is_timeout_enabled = $socket->timeout_enabled();
  $socket->timeout_enabled(0);

Get or Set the fact that a socket has timeouts enabled.

=head1 CHANGE SETTINGS AFTER CREATION

You can change the timeout settings of a socket after it has been instanciated.

  use IO::Socket::With::Timeout;
  # create a socket with read timeout
  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     # other standard arguments );
  # change read_timeout to 5 and write timeout to 1.5 sec
  $socket->read_timeout(5)
  $socket->write_timeout(1.5)
  # actually disable the timeout for now
  $socket->disable_timeout()
  # when re-enabling it, timeouts value are restored
  $socket->enable_timeout()

=head1 WHEN TIMEOUT IS HIT

When a timeout (read, write) is hit on the socket, the function trying to be
performed will return C<undef> or empty string, and C<$!> will be set to
C<ETIMEOUT> or C<EWOULDBLOCK>. You should test for both.

You can import C<ETIMEOUT> and C<EWOULDBLOCK> by using C<POSIX>:

  use Errno qw(ETIMEDOUT EWOULDBLOCK);

=head1 IF YOU NEED TO RETRY

If you want to implement a try / wait / retry mechanism, I recommend using a
third-party module, like C<Action::Retry>. Something like this:

  my $socket;

  my $answer;
  my $action = Action::Retry->new(
    attempt_code => sub {
        # (re-)create the socket if needed
        $socket && ! $socket->error
          or $socket = IO::Socket->new::with::timeout(ReadTimeout => 0.5);
        # send the request, read the answer
        $socket->print($_[0]);
        defined($answer = $socket->getline) or die $!;
        $answer;
    },
    on_failure_code => sub { die 'aborting, to many retries' },
  );

  my $reply = $action->run('GET mykey');

=head1 SEE ALSO

L<Action::Retry>, L<IO::Select>, L<PerlIO::via::Timeout>, L<Time::Out>

=head1 THANKS

Thanks to Vincent Pitt, Christian Hansen and Toby Inkster for various help and
useful remarks.

=cut

sub new::with::timeout {
    my $class = shift
      or croak "needs a class name. Try IO::Socket::INET->new::with::timeout(...)";

    my $class_file = $class;
    $class_file =~ s!::|'!/!g;
    $class_file .= '.pm';
    require $class_file;

    $class->isa('IO::Socket')
      or croak 'new::with::timeout can be used only on classes that isa IO::Socket';

    # if arguments are not key values, just original class constructor
    @_ % 2
      and return $class->new(@_);

    my %args = @_;

    my $read_timeout = delete $args{ReadTimeout};
    my $write_timeout = delete $args{WriteTimeout};
    if (defined (my $readwrite_timeout = delete $args{ReadWriteTimeout})) {
        $read_timeout = $write_timeout = $readwrite_timeout;
    }
    
    my $socket = $class->new(%args)
      or return;

    my $osname = $Config{osname};
    if ( ! $ENV{PERL_IO_SOCKET_TIMEOUT_FORCE_SELECT}
         && ( $osname eq 'darwin' || $osname eq 'linux' ) ) {
        _compose_roles($socket, 'IO::Socket::Timeout::Role::SetSockOpt');
    } else {
        require PerlIO::via::Timeout;
        binmode($socket, ':via(Timeout)');
        _compose_roles($socket, 'IO::Socket::Timeout::Role::PerlIO');
    }

    $read_timeout && $read_timeout > 0
      and $socket->read_timeout($read_timeout);
    $write_timeout && $write_timeout > 0
      and $socket->write_timeout($write_timeout);
    $socket->enable_timeout;

    return $socket;
}

sub socketpair::with::timeout {
    my $class = shift
      or croak "needs a class name. Try IO::Socket::INET->socketpair::with::timeout(...)";

    my $class_file = $class;
    $class_file =~ s!::|'!/!g;
    $class_file .= '.pm';
    require $class_file;

    $class->isa('IO::Socket')
      or croak 'new::with::timeout can be used only on classes that isa IO::Socket';

    # we expect DOMAIN, TYPE, PROTOCOL, TIMEOUT_ARGS. Otherwise just call original
    @_ == 4
      or return $class->socketpair(@_);

    my $timeout_args = pop;

    my %args = %$timeout_args;
    my $read_timeout = delete $args{ReadTimeout};
    my $write_timeout = delete $args{WriteTimeout};
    if (defined (my $readwrite_timeout = delete $args{ReadWriteTimeout})) {
        $read_timeout = $write_timeout = $readwrite_timeout;
    }

    my ($socket1, $socket2) = $class->socketpair(%args)
       or return;

    my $osname = $Config{osname};
    foreach my $socket ($socket1, $socket2) {
        if ( ! $ENV{PERL_IO_SOCKET_TIMEOUT_FORCE_SELECT}
             && ( $osname eq 'darwin' || $osname eq 'linux' ) ) {
            _compose_roles($socket, 'IO::Socket::Timeout::Role::SetSockOpt');
        } else {
            require PerlIO::via::Timeout;
            binmode($socket, ':via(Timeout)');
            _compose_roles($socket, 'IO::Socket::Timeout::Role::PerlIO');
        }
        $read_timeout && $read_timeout > 0
          and $socket->read_timeout($read_timeout);
        $write_timeout && $write_timeout > 0
          and $socket->write_timeout($write_timeout);
    }
    return ($socket1, $socket2);
}

sub _compose_roles {
    my ($instance, @roles) = @_;
    my $class = ref $instance;
    my $composed_class = $class . '__with__' . join('__and__', @roles);
    my $path = $composed_class; $path =~ s|::|/|g; $path .= '.pm';
    if ( ! exists $INC{$path}) {
        no strict 'refs';
        *{"${composed_class}::ISA"} = [ $class, @roles ];
        $INC{$path} = __FILE__;
    }
    bless $instance, $composed_class;
}

# sysread FILEHANDLE,SCALAR,LENGTH,OFFSET
BEGIN {
    my $osname = $Config{osname};
    if ( $ENV{PERL_IO_SOCKET_TIMEOUT_FORCE_SELECT} ||
         $osname ne 'darwin' && $osname ne 'linux'
       ) {
        # this variable avoids infinite recursion, because
        # PerlIO::via::Timeout->READ calls sysread.
        my $_prevent_deep_recursion;
        *CORE::GLOBAL::sysread = sub {
            $_prevent_deep_recursion || ! PerlIO::via::Timeout->_fh2prop($_[0])->{timeout_enabled}
              and return CORE::sysread($_[0], $_[1], $_[2], $_[3]);
            $_prevent_deep_recursion = 1;
            require PerlIO::via::Timeout;
            my $ret_val = PerlIO::via::Timeout->READ($_[1], $_[2], $_[0]);
            $_prevent_deep_recursion = 0;
            return $ret_val;
        }
    }
}

# syswrite FILEHANDLE,SCALAR,LENGTH,OFFSET
BEGIN {
    my $osname = $Config{osname};
    if ( $ENV{PERL_IO_SOCKET_TIMEOUT_FORCE_SELECT} ||
         $osname ne 'darwin' && $osname ne 'linux'
       ) {
        # this variable avoids infinite recursion, because
        # PerlIO::via::Timeout->WRITE calls syswrite.
        my $_prevent_deep_recursion;
        *CORE::GLOBAL::syswrite = sub {
            $_prevent_deep_recursion || ! PerlIO::via::Timeout->_fh2prop($_[0])->{timeout_enabled}
              and return CORE::syswrite($_[0], $_[1], $_[2], $_[3]);
            $_prevent_deep_recursion = 1;
            require PerlIO::via::Timeout;
            my $ret_val = PerlIO::via::Timeout->WRITE($_[1], $_[0]);
            $_prevent_deep_recursion = 0;
            return $ret_val;
        }
    }
}

package IO::Socket::Timeout::Role::SetSockOpt;
use Carp;
use Socket;

sub _check_attributes {
    my ($self) = @_;
    grep { $_ < 0 } grep { defined } map { ${*$self}{$_} } qw(ReadTimeout WriteTimeout)
      and croak "if defined, 'ReadTimeout' and 'WriteTimeout' attributes should be >= 0";
}

sub read_timeout {
    my ($self) = @_;
    @_ > 1 and ${*$self}{ReadTimeout} = $_[1], $self->_check_attributes, $self->_set_sock_opt;
    ${*$self}{ReadTimeout}
}

sub write_timeout {
    my ($self) = @_;
    @_ > 1 and ${*$self}{WriteTimeout} = $_[1], $self->_check_attributes, $self->_set_sock_opt;
    ${*$self}{WriteTimeout}
}

sub enable_timeout { $_[0]->timeout_enabled(1) }
sub disable_timeout { $_[0]->timeout_enabled(0) }
sub timeout_enabled {
    my ($self) = @_;
    @_ > 1 and ${*$self}{TimeoutEnabled} = !!$_[1], $self->_set_sock_opt;
    ${*$self}{TimeoutEnabled}
}

sub _set_sock_opt {
    my ($self) = @_;
    my $read_seconds;
    my $read_useconds;
    my $write_seconds;
    my $write_useconds;
    if (${*$self}{TimeoutEnabled}) {
        my $read_timeout = ${*$self}{ReadTimeout} || 0;
        $read_seconds  = int( $read_timeout );
        $read_useconds = int( 1_000_000 * ( $read_timeout - $read_seconds ));
        my $write_timeout = ${*$self}{WriteTimeout} || 0;
        $write_seconds  = int( $write_timeout );
        $write_useconds = int( 1_000_000 * ( $write_timeout - $write_seconds ));
    } else {
        $read_seconds  = 0; $read_useconds  = 0;
        $write_seconds = 0; $write_useconds = 0;
    }
    my $read_struct  = pack( 'l!l!', $read_seconds, $read_useconds );
    my $write_struct = pack( 'l!l!', $write_seconds, $write_useconds );

    $self->setsockopt( SOL_SOCKET, SO_RCVTIMEO, $read_struct )
      or croak "setsockopt(SO_RCVTIMEO): $!";

    $self->setsockopt( SOL_SOCKET, SO_SNDTIMEO, $write_struct )
      or croak "setsockopt(SO_SNDTIMEO): $!";
}

package IO::Socket::Timeout::Role::PerlIO;
use PerlIO::via::Timeout;

sub read_timeout    { goto &PerlIO::via::Timeout::read_timeout    }
sub write_timeout   { goto &PerlIO::via::Timeout::write_timeout   }
sub enable_timeout  { goto &PerlIO::via::Timeout::enable_timeout  }
sub disable_timeout { goto &PerlIO::via::Timeout::disable_timeout }
sub timeout_enabled { goto &PerlIO::via::Timeout::timeout_enabled }

1;
