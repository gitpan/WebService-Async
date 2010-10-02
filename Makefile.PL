use inc::Module::Install;
name 'WebService-Async';
all_from 'lib/WebService/Async.pm';
readme_from 'lib/WebService/Async.pm';
readme_markdown_from 'lib/WebService/Async.pm';
readme_pod_from 'lib/WebService/Async.pm';
githubmeta;

requires 'AnyEvent';
requires 'AnyEvent::HTTP';
requires 'Carp';
requires 'Class::MOP';
requires 'Clone';
requires 'Data::UUID';
requires 'Encode';
requires 'Hash::MultiKey';
requires 'JSON';
requires 'Log::Dispatch::Config';
requires 'Smart::Args';
requires 'Moose';
requires 'Moose::Role';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::WithCache';
requires 'Regexp::Common';
requires 'Scalar::Util';
requires 'URI::Escape';
requires 'XML::Simple';

build_requires 'Test::More';
build_requires 'Test::Deep';
build_requires 'Test::Exception';
build_requires 'Test::TCP';
build_requires 'UNIVERSAL';
build_requires 'Plack';

recommends 'Log::Dispatch::Configurator::YAML';

tests 't/*.t';
author_tests 'xt';

auto_set_repository;
auto_include;
WriteAll;
