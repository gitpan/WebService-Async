#line 1
package UNIVERSAL;

our $VERSION = '1.04';

# UNIVERSAL should not contain any extra subs/methods beyond those
# that it exists to define. The use of Exporter below is a historical
# accident that can't be fixed without breaking code.  Note that we
# *don't* set @ISA here, as we don't want all classes/objects inheriting from
# Exporter.  It's bad enough that all classes have a import() method
# whenever UNIVERSAL.pm is loaded.
require Exporter;
@EXPORT_OK = qw(isa can VERSION);

# Make sure that even though the import method is called, it doesn't do
# anything unless called on UNIVERSAL.
sub import {
    return unless $_[0] eq __PACKAGE__;
    goto &Exporter::import;
}

1;
__END__

#line 194
