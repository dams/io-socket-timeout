package IO::Socket::Timeout::Strategy::Select;

use strict;
use warnings;
use Time::HiRes;
use IO::Select;

use Class::Method::Modifiers qw(install_modifier);
use POSIX qw(ETIMEDOUT ECONNRESET);
use Carp;

use base qw(IO::Socket::Timeout::Strategy);

# ABSTRACT: proxy to read/write using IO::Select as a timeout provider

sub apply_to_class {
    my $class = shift;
    my ($into, $timeout_read, $timeout_write) = @_;

    $class->SUPER::apply_to_class(@_);

    my @wrap_read_functions = qw(getc getline gets getlines);
    my @wrap_read_functions_with_buffer = qw(recv sysread read);
    my @wrap_write_functions = qw( ungetc print printf say truncate);
    my @wrap_write_functions_with_buffer = qw(send syswrite write);

    if ($timeout_read) {
        install_modifier($into, 'around', $_, \&read_wrapper)
          foreach @wrap_read_functions, @wrap_read_functions_with_buffer;
    }

    if ($timeout_write) {
        install_modifier($into, 'around', $_, \&write_wrapper)
          foreach @wrap_write_functions, @wrap_write_functions_with_buffer;
    }
}

sub apply_to_instance {
    my ($class, $socket, $into, $timeout_read, $timeout_write) = @_;
    ${*$socket}{__timeout_read__} = $timeout_read;
    ${*$socket}{__timeout_write__} = $timeout_write;
    ${*$socket}{__is_valid__} = 1;
    ${*$socket}{__select__} = IO::Select->new;
    ${*$socket}{__select__}->add($socket);
    return $socket;
}

sub cleanup_socket {
    my ($class, $socket) = @_;
    ${*$socket}{__select__}->remove( $socket );
    $class->SUPER::cleanup_socket($socket);
}

sub read_wrapper {
    my $orig = shift;
    my $self = shift;

    defined ${*$self}{__is_valid__}
      or return $orig->($self, @_);

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    ${*$self}{__select__}->can_read(${*$self}{__timeout_read__})
      and return $orig->($self, @_);

    __PACKAGE__->cleanup_socket($self);
    $! = ETIMEDOUT;
    return;
}

sub write_wrapper {
    my $orig = shift;
    my $self = shift;

    defined ${*$self}{__is_valid__}
      or return $orig->($self, @_);

    ${*$self}{__is_valid__} or $! = ECONNRESET, return;

    ${*$self}{__select__}->can_write(${*$self}{__timeout_write__})
      and return $orig->($self, @_);

    __PACKAGE__->cleanup_socket($self);
    $! = ETIMEDOUT;
    return;
}

1;
