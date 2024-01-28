use v6.d;
use DB::Migration::Declare::Model;
use DB::Migration::Declare::SQLLiteral;

sub migration(Str $description, &spec --> Nil) is export {
    with $*DMD-MIGRATION-LIST -> $list {
        my $file = &spec.?file // 'Unknwon';
        my $line = &spec.?line // 0;
        my $*DMD-MODEL = DB::Migraion::Declare::Model::Migration.new(:$description, :$file, :$line);
        spec();
        $list.add-migration($*DMD-MODEL);
    }
    else {
        die "Can only use `migration` when a migration list is set up to collect them";
    }
}

sub create-table(Str $name, &spec --> Nil) is export {
    ensure-in-migrate('create-table');
    my $*DMD-MODEL-TABLE = DB::Migraion::Declare::Model::CreateTable.new(:$name);
    $*DMD-MODEL.add-step($*DMD-MODEL-TABLE);
    my Str @*PRIMARIES;
    my Str @*UNIQUES;
    spec();
    primary-key |@*PRIMARIES if @*PRIMARIES;
    unique-key $_ for @*UNIQUES;
}

sub alter-table(Str $name, &spec --> Nil) is export {
    ensure-in-migrate('alter-table');
    my $*DMD-MODEL-TABLE = DB::Migraion::Declare::Model::AlterTable.new(:$name);
    $*DMD-MODEL.add-step($*DMD-MODEL-TABLE);
    my Str @*UNIQUES;
    spec();
    unique-key $_ for @*UNIQUES;
}

multi sub rename-table(Str $from, Str $to --> Nil) is export {
    ensure-in-migrate('rename-table');
    $*DMD-MODEL.add-step(DB::Migraion::Declare::Model::RenameTable.new(:$from, :$to));
}

multi sub rename-table(Str :$from!, Str :$to! --> Nil) is export {
    rename-table($from, $to);
}

multi sub rename-table(Pair $renaming --> Nil) is export {
    rename-table(~$renaming.key, ~$renaming.value);
}

sub drop-table(Str $name --> Nil) is export {
    ensure-in-migrate('drop-table');
    $*DMD-MODEL.add-step(DB::Migraion::Declare::Model::DropTable.new(:$name));
}

sub add-column(Str $name, $type, Bool :$increments, Bool :$null = !$increments, Any :$default,
        Bool :$primary, Bool :$unique --> Nil) is export {
    ensure-in-table('add-column');
    $*DMD-MODEL-TABLE.add-step: DB::Migraion::Declare::Model::AddColumn.new:
            :$name, :type(parse-type($type, "of column '$name'")), :$null, :$default, :$increments;
    @*UNIQUES.push($name) if $unique;
    if $primary {
        if $*DMD-MODEL-TABLE ~~ DB::Migraion::Declare::Model::CreateTable {
            @*PRIMARIES.push($name);
        }
        else {
            die "Can only use the :primary option on a column within the scope of create-table;\n" ~
                    "use a separate primary-key call if you really wish to change the primary key of the table";
        }
    }
}

multi rename-column(Str $from, Str $to --> Nil) is export {
    ensure-in-alter-table('rename-column');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::RenameColumn.new(:$from, :$to));
}

multi rename-column(Str :$from!, Str :$to! --> Nil) is export {
    rename-column($from, $to);
}

multi rename-column(Pair $renaming --> Nil) is export {
    rename-column(~$renaming.key, ~$renaming.value);
}

sub drop-column(Str $name --> Nil) is export {
    ensure-in-alter-table('drop-column');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::DropColumn.new(:$name));
}

sub primary-key(*@column-names --> Nil) is export {
    ensure-in-table('primary-key');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::PrimaryKey.new(:@column-names));
}

sub unique-key(*@column-names --> Nil) is export {
    ensure-in-table('unique-key');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::UniqueKey.new(:@column-names));
}

sub drop-unique-key(*@column-names --> Nil) is export {
    ensure-in-table('drop-unique-key');
    $*DMD-MODEL-TABLE.add-step(DB::Migraion::Declare::Model::DropUniqueKey.new(:@column-names));
}

multi sub foreign-key(Str :$from!, Str :$table!, Str :$to = $from, Bool :$restrict = False,
                      Bool :$cascade = False --> Nil) is export {
    foreign-key :from[$from], :$table, :to[$to], :$restrict, :$cascade
}
multi sub foreign-key(:@from!, Str :$table!, :@to = @from, Bool :$restrict = False,
                      Bool :$cascade = False --> Nil) is export {
    $*DMD-MODEL-TABLE.add-step: DB::Migraion::Declare::Model::ForeignKey.new:
            :@from, :$table, :@to, :$restrict, :$cascade
}
sub foriegn-key(|c) is export is DEPRECATED {
    foreign-key(|c)
}

multi sub execute(DB::Migration::Declare::SQLLiteral :$up!, DB::Migration::Declare::SQLLiteral :$down! --> Nil) is export {
    ensure-in-migrate('execute');
    $*DMD-MODEL.add-step(DB::Migraion::Declare::Model::ExecuteSQL.new(:$up, :$down));
}


sub char(Int $length --> DB::Migration::Declare::ColumnType::Char) is export {
    DB::Migration::Declare::ColumnType::Char.new(:$length, :!varying)
}

sub varchar(Int $length --> DB::Migration::Declare::ColumnType::Char) is export {
    DB::Migration::Declare::ColumnType::Char.new(:$length, :varying)
}

sub text(--> DB::Migration::Declare::ColumnType::Text) is export {
    DB::Migration::Declare::ColumnType::Text.new
}

sub boolean(--> DB::Migration::Declare::ColumnType::Boolean) is export {
    DB::Migration::Declare::ColumnType::Boolean.new
}

sub integer(Int $bytes = 4 --> DB::Migration::Declare::ColumnType::Integer) is export {
    DB::Migration::Declare::ColumnType::Integer.new(:$bytes)
}

sub date(--> DB::Migration::Declare::ColumnType::Date) is export {
    DB::Migration::Declare::ColumnType::Date.new
}

sub timestamp(Bool :$timezone = False --> DB::Migration::Declare::ColumnType::Timestamp) is export {
    DB::Migration::Declare::ColumnType::Timestamp.new(:$timezone)
}

sub arr($type, *@dimensions --> DB::Migration::Declare::ColumnType::Array) is export {
    @dimensions ||= *;
    my $element-type = parse-type($type, 'of array type');
    for @dimensions {
        when Whatever {}
        when Int {}
        default {
            die "Unrecognized array dimension specifier; must be Int or *";
        }
    }
    DB::Migration::Declare::ColumnType::Array.new(:$element-type, :@dimensions)
}

sub type(Str $name, Bool :$checked = True --> DB::Migration::Declare::ColumnType::Named) is export {
    DB::Migration::Declare::ColumnType::Named.new(:$name, :$checked)
}


multi sub sql(Str $sql --> DB::Migration::Declare::SQLLiteral::Agnostic) is export {
    DB::Migration::Declare::SQLLiteral::Agnostic.new(:$sql)
}

multi sub sql(*%options --> DB::Migration::Declare::SQLLiteral::Specific) is export {
    DB::Migration::Declare::SQLLiteral::Specific.new(:%options)
}

sub now(--> DB::Migration::Declare::SQLLiteral::Now) is export {
    DB::Migration::Declare::SQLLiteral::Now.new
}


multi parse-type(DB::Migration::Declare::ColumnType $type, Str --> DB::Migration::Declare::ColumnType) {
    # Already a column type specification object, so just return it.
    $type
}

multi parse-type(Any $type, Str $hint) {
    die "Cannot parse type '$type.raku()' $hint"
}

sub ensure-in-migrate(Str $what --> Nil) {
    without $*DMD-MODEL {
        die "Can only use $what within the scope of a migration";
    }
}

sub ensure-in-table(Str $what --> Nil) {
    without $*DMD-MODEL-TABLE {
        die "Can only use $what within the scope of create-table or alter-table";
    }
}

sub ensure-in-alter-table(Str $what --> Nil) {
    unless $*DMD-MODEL-TABLE ~~ DB::Migraion::Declare::Model::AlterTable {
        die "Can only use $what within the scope of alter-table";
    }
}

=begin pod

=head1 NAME

DB::Migration::Declare - Specify database migrations using a Raku DSL

=head1 SYNOPSIS

=begin code :lang<raku>

use DB::Migration::Declare;

migration 'Setup', {
  create-table 'skyscrapers', {
    add-column 'id', integer(), :increments, :primary;
    add-column 'name', text(), :!null, :unique;
    add-column 'height', integer(), :!null;
  }
}

=end code

=head1 DESCRIPTION

Database migrations are an ordered, append-only list of database
change operations that together bring the database up to a current
schema. A table in the database is used to track which migrations
have been applied so far, so that the database can be brought up
to date by applying the latest migrations.

This module allows one to specify database migrations using a Raku
DSL. The migrations are checked in various ways for correctness
(for example, trying to drop a table that never existed, or adding
duplicate columns), and are then translated into SQL and applied
to the database.

If one is using a Raku ORM such as C<Red>, it is probably worth looking
into how it might assist with migrations. This module is more aimed
at those writing their queries in SQL, perhaps using something like
C<Badger> to have those SQL queries neatly wrapped up in Raku subs and
thus avoid inline SQL.

B<Warning>: The module should currently be considered as a BETA-quality
minimum viable product. Of note, only Postgres support is currently
available, migrations can only be applied in the "up" direction, and
various kinds of database change are not yet implemented.

=head1 Setup

=head2 Writing migrations

Migrations can be written in a single file or spread over multiple
files in a single directory, where the filenames will be used as the
ordering. For now we'll assume there is a single file C<migrations.raku>
where the migrations will be written one after the other.

A migration file with a single migration looks like this:

=begin code :lang<raku>

use DB::Migration::Declare;

migration 'Setup', {
  create-table 'skyscrapers', {
    add-column 'id', integer(), :increments, :primary;
    add-column 'name', text(), :!null, :unique;
    add-column 'height', integer(), :!null;
  }
}

=end code

Future changes to the database are specified by writing another
migration at the end of the file. For example, after adding another
migration the file overall could look as follows:

=begin code :lang<raku>

use DB::Migration::Declare;

migration 'Setup', {
  create-table 'skyscrapers', {
    add-column 'id', integer(), :increments, :primary;
    add-column 'name', text(), :!null, :unique;
    add-column 'height', integer(), :!null;
  }
}

migration 'Add countries', {
  create-table 'countries', {
    add-column 'id', integer(), :increments, :primary;
    add-column 'name', varchar(255), :!null, :unique;
  }

  alter-table 'skyscrapers',{
    add-column 'country', integer();
    foreign-key table => 'countries', from => 'country', to => 'id';
  }
}

=end code

=head2 Testing migrations

When a project has migrations, it is wise to write a test case to
check that the list of migrations are well-formed. This following
can be placed in a C<t/migrations.rakutest>:

=begin code :lang<raku>

use DB::Migration::Declare::Database::Postgres;
use DB::Migration::Declare::Test;
use Test;

check-migrations
  source   => $*PROGRAM.parent.parent.add('migrations.raku'),
  database => DB::Migration::Declare::Database::Postgres.new;

done-testing;

=end code

Which will produce the output:

=begin code

ok 1 - Setup
ok 2 - Add countries
1..2

=end code

If we were to introduce an error into the migration:

=begin code :lang<raku>

alter-table 'skyskrapers', {
  add-column 'country', integer();
  foreign-key table => 'countries', from => 'country', to => 'id';
}

=end code

The test would fail:

=begin code

ok 1 - Setup
not ok 2 - Add countries
# Failed test 'Add countries'
# Migration at migrations.raku:11 has problems:
#   Cannot alter non-existent table 'skyskrapers'
1..2
# You failed 1 test of 2

=end code

With diagnostics indicating what is wrong. (If following this getting
started guide like a tutorial, undo the change introducing an error
before continuing!)

=head2 Applying migrations

To migrate a database to the latest version, assuming we are placing
this in a C<service.raku> script, do this:

=begin code :lang<raku>

use DB::Migration::Declare::Applicator;
use DB::Migration::Declare::Database::Postgres;
use DB::Pg;

my $conn = $pg.new(:conninfo('...write your connection string here...'));

my $applicator = DB::Migration::Declare::Applicator.new:
  schema-id => 'my-project',
  source => $*PROGRAM.parent.add('migrations.raku'),
  database => DB::Migration::Declare::Database::Postgres.new,
  connection => $conn;

my $status = $applicator.to-latest;
note "Applied $status.migrations.elems() migration(s)";

=end code

Depending on your situation, you might have this as a distinct script,
or place it in the startup script for a Cro service to run the
migrations upon startup.

=head1 Migration DSL

Top-level operations supported within a migration are:

=item C<create-table(Str $name, &steps)>

=item C<alter-table(Str $name, &steps)>

=item C<rename-table(Str $from, Str $to)> (or
C<rename-table(Str :$from!, Str :$to!)> or
C<rename-table(Pair $renmaing)>)

=item C<drop-table(Str $name)>
=item C<execute(SQLLiteral :$up!, SQLLiteral :$down!)>

Within both C<create-table> and C<alter-table> one can use:

=item C<add-column(Str $name, $type, Bool :$increments, Bool :$null,
Any :$default, Bool :$primary, Bool :$unique)>

=item C<primary-key(*@column-names)>

=item C<unique-key(*@column-names)>

=item C<foreign-key(Str :$from!, Str :$table!, Str :$to = $from,
Bool :$restrict = False, Bool :$cascade = False)>

=item C<foreign-key(:@from!, Str :$table!, :@to = @from,
Bool :$restrict = False, Bool :$cascade = False)>

Only within C<alter-table> one can use:

=item C<rename-column(Str $from, Str $to)>
(or C<rename-column(Str :$from!, Str :$to!)>
or C<rename-column(Pair $renmaing)>)

=item C<drop-column(Str $name)>

=item C<drop-unique-key(*@column-names)>

Column types are specified using any of the following functions:

=item C<char(Int $length)>

=item C<varchar(Int $length)>

=item C<text()>

=item C<boolean()>

=item C<integer(Int $bytes = 4)> (only 2, 4, and 8 are reliably
supported)

=item C<date()>

=item C<timestamp(Bool :$timezone = False)> (a date/time)

=item C<arr($type, *@dimensions)> (dimensions are integers for
fixed size of C<*> for variable size; specifying no dimensions
results in a variable-length single dimensional array)

=item C<type(Str $name, Bool :$checked = True)> (any other type,
checked by the database backend against a known type list by default,
but trusted and passed along regardless if C<:!checked>)

SQL literals can be constructed either:

=item Database agnostic: C<sql(Str $sql)>

=item Database specific: C<sql(*%options)> (where the named argument
names are database IDs, such as C<postgres>, and the argument value
is the SQL) 

=item Polymorphic "now": C<now()> (becomes the Right Thing depending
on database and column type when used as the default value of a date
or timestamp column)

=head1 Planned Features

=head2  Migration DSL

=item Indexes (currently only those implied by keys are available)

=item Key and index dropping

=item Column type and constraint alteration

=item Column type declaration using Raku types

=item Views

=item Stored procedures

=item Table-valued functions

=head2 Tooling

=item CLI: view migration history on a database against what is applied

=item CLI: trigger up/down migrations

=item CLI: use information schema to extract an initial migration and
set things up as if it was already applied, to ease getting started

=item Comma: add migrations dependency, tests, etc.

=item Comma: live annotation of migration problems

=head2 Other

=item Seed data insertion

=item Schema export

=item Down migrations

=item Configurable data retention on lossy migrations in either direction

=item Other database support (SQLite, MySQL)

=head1 AUTHOR

Jonathan Worthington

=head1 COPYRIGHT AND LICENSE

Copyright 2022 - 2024 Jonathan Worthington

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
