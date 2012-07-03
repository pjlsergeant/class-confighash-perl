package Class::ConfigHash;

use strict;
use warnings;
use Carp qw/croak/;

=head1 NAME

Class::ConfigHash - Boxing for hashes containing config value

=head1 DESCRIPTION

Boxing for hashes containing config value

=head1 SYNOPSIS

 my $config = Class::ConfigHash->_new({
    database => {
        user => 'rodion',
        pass => 'bonaparte',
        options => {
            city => 'St Petersburg'
        },
    },
 });

 $config->database->options->city; # St Petersburg

 # Dies: Can't find 'flags' at [/->database]. Options: [options; pass; user]
 $config->database->flags;

 # Won't die, returns undef
 $config->database->flags({ allow_undef => 1 });

 # Won't die, returns 'foo'
 $config->database->flags({ default => 'foo' });

 # Access the underlying structure
 $config->database({ raw => 1 })->{'user'} = 'raskolnikov';

=head1 METHODS

=head2 _new

Instantiates a new object. Preceeding underscore to stop collisions on hash
keys. Accepts a hashref and an ArrayRef of strings, representing the depth
that this hash is found at (defaults to C<['/']>).

You will probably never need to specify the depth yourself - instead:

 my $config = Class::ConfigHash->_new( $hashref );

=cut

sub _new {
    my ( $class, $hash, $path ) = @_;
    # Allow instantiation from existing object
    $class = ref $class if ref $class;
    # Default path to be the root
    $path ||= ['/'];

    bless {
        '_raw' => $hash,
        'path' => $path ? [@$path] : ['/'],
    }, $class;
}

=head2 *

Every other method call tries to lookup the method name as a hashkey.

 # Logically looks up ->{'configuration'}->{'database'}->{'host'} in wrapped hash
 my $host = $obj->configuration->database->host;

When a key doesn't exist a fatal error with helpful advice is thrown.

You can pass in some options as a hashref:

C<raw> - Boolean - returns the item at the key, rather than attempting to wrap it

C<allow_undef> - Boolean - returns undef rather than throwing an error if key
doesn't exist

C<default> - Any value - returns this value rather than throwing an error if key doesn't exist.

eg:

 # Don't get upset if host doesn't exist
 $obj->configuration->database->host({ allow_undef => 1 })

=cut

sub AUTOLOAD {
    my $self = shift;
    my $options = shift;

    my $type = ref($self) or croak "$self isn't a config object - it's a class. Did you accidentally use new() instead of _new()?";

    our $AUTOLOAD;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion

    unless ( exists $self->{'_raw'}->{$name} ) {
        if ( $options && ref $options eq 'HASH' ) {
            return $options->{'default'} if exists $options->{'default'};
            return undef if $options->{'allow_undef'};
        }

        croak( sprintf("Can't find '%s' at [%s]. Options: [%s]",
            $name,
            ( join '->', @{ $self->{'path'} } ),
            ( join '; ', sort keys %{ $self->{'_raw'} } )
        ));
    }

    my $item = $self->{'_raw'}->{$name};
    if ( $options && $options->{'raw'} ) {
        return $item;
    } elsif ( ref( $item ) eq 'HASH' ) {
        return $self->_new( $item, [@{$self->{'path'}}, $name ] );
    } else {
        return $item;
    }
}

# Don't want this hitting AUTOLOAD, obv
sub DESTROY {}

=head1 SEE ALSO

This is pretty similar to L<Class::Hash>, except it's intended to be simply for
configuration hashes, so there's no easy way to set values, there are defaults,
and the error message gives you an overview of the different options you might
want, and we autobox hashref children.

Module inspired by L<this patch to Dancer|http://blogs.perl.org/users/ovid/2012/03/hacking-on-dancer.html>

=head1 AUTHOR

Peter Sergeant C<pete@clueball.com> - written while working for the excellent
L<Net-A-Porter|http://www.net-a-porter.com/>.

=cut

1;