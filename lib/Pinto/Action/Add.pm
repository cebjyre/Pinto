package Pinto::Action::Add;

# ABSTRACT: An action to add one archive to the repository

use Moose;

use Carp;
use File::Copy;
use Dist::Metadata;

use Pinto::Util;
use Pinto::IndexManager;
use Pinto::Types qw(File);

extends 'Pinto::Action';

use namespace::autoclean;

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------
# Attrbutes

has file => (
    is       => 'ro',
    isa      => File,
    required => 1,
    coerce   => 1,
);

#------------------------------------------------------------------------------
# Roles

with qw( Pinto::Role::Authored );

#------------------------------------------------------------------------------

override execute => sub {
    my ($self) = @_;

    my $local  = $self->config->local();
    my $author = $self->author();

    my $file   = $self->file();
    my $base   = $file->basename();

    # Refactor to sub
    croak "$file does not exist"  if not -e $file;
    croak "$file is not readable" if not -r $file;
    croak "$file is not a file"   if not -f $file;

    # Refactor to sub
    my $idxmgr = $self->idxmgr();
    if ( my $existing = $idxmgr->find_file(author => $author, file => $file) ) {
        croak "Archive $base already exists as $existing";
    }

    # Refactor to sub
    # Dist::Metadata will croak for us if $file is whack!
    my $distmeta = Dist::Metadata->new(file => $file->stringify());
    my $provides = $distmeta->package_versions();
    return 0 if not %{ $provides };

    # Refactor to sub
    my @conflicts = ();
    for my $package_name (sort keys %{ $provides }) {
        if ( my $orig_author = $idxmgr->local_author_of(package => $package_name) ) {
            push @conflicts, "Package $package_name is already owned by $orig_author\n"
                if $orig_author ne $author;
        }
    }
    die @conflicts if @conflicts;

    # Refactor to sub
    my @packages = ();
    for my $package_name (sort keys %{ $provides }) {

        my $version = $provides->{$package_name} || 'undef';
        $self->logger->log("Adding package $package_name $version");
        push @packages, Pinto::Package->new( name    => $package_name,
                                             file    => $file,
                                             version => $version,
                                             author  => $author );
    }


    $self->idxmgr()->add_local_packages(@packages);

    my $destination = Pinto::Util::author_dir($local, qw(authors id), $author)->file($base);
    $self->store->add(file => $destination, source => $file);

    my $message = Pinto::Util::format_message("Added archive $base providing:", sort keys %{$provides});
    $self->_set_message($message);

    return 1;
};

#------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable();

#-----------------------------------------------------------------------------
1;

__END__
