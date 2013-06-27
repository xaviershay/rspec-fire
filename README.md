rspec-fire
==========

Checks that stubbed methods on your test double exist, but still allow you to run in isolation
when you choose. A failure will be triggered if an invalid method is being stubbed.

    Once,
    a younger brother came to him,
    and asked,

    "Father,
    I have made and kept my little rule,
    my fast,
    my meditation and silence.
    I strived to cleanse my heart of thoughts,
    what more must I do?"

    The elder rose up and,
    stretched out his hands,
    his fingers became like ten lamps ablaze.
    He said,

    "Why not be totally changed into fire?"

      -- Desert Way, Charlie Hunter

Test doubles are sweet for isolating your unit tests, but we lost something in
the translation from typed languages. Ruby doesn't have a compiler that can
verify the contracts being mocked out are indeed legit. This hurts larger
refactorings, since you can totally change a collaborator --- renaming methods,
changing the number of arguments --- and all the mocks that were standing in
for it will keep pretending everything is ok.

`rspec-fire` mitigates that problem, with very little change to your existing
coding style.

One solution would be to disallow stubbing of methods that don't exist. This is
what mocha does with its
`Mocha::Configuration.prevent(:stubbing_non_existent_method)` option. The
downside is, you now have to load the collaborators/dependencies that you are
mocking, which kind of defeats the purpose of isolated testing. Not ideal.

Another solution, that `rspec-fire` adopts, is a more relaxed version that only
checks that the methods exist _if the doubled class has already been loaded_.
No checking will happen when running the spec in isolation, but when run in the
context of the full app (either as a full spec run or by explicitly preloading
collaborators on the command line) a failure will be triggered if an invalid
method is being stubbed.

Usage
-----

It's a gem!

    gem install rspec-fire

Bit of setup in your `spec_helper.rb`:

    require 'rspec/fire'

    RSpec.configure do |config|
      config.include(RSpec::Fire)
    end

Specify the class being doubled in your specs:

    class User < Struct.new(:notifier)
      def suspend!
        notifier.notify("suspended as")
      end
    end

    describe User, '#suspend!' do
      it 'sends a notification' do
        # Only this one line differs from how you write specs normally
        notifier = instance_double("EmailNotifier")

        notifier.should_receive(:notify).with("suspended as")

        user = User.new(notifier)
        user.suspend!
      end
    end

Run your specs:

    # Isolated, will pass always
    rspec spec/user_spec.rb

    # Will fail if EmailNotifier#notify method is not defined
    rspec -Ilib -remail_notifier.rb spec/user_spec.rb

Method presence/absence is checked, and if a `with` is provided then so is
arity.

Protips
-------

### Using with an existing Rails project

Create a new file `unit_helper.rb` that _does not_ require `spec_helper.rb`.
Require this file where needed for isolated tests. To run an isolated spec in
the context of your app:

    rspec -r./spec/spec_helper.rb spec/unit/my_spec.rb

### Using with ActiveRecord

ActiveRecord methods defined implicitly from database columns are not detected.
A workaround is to explicitly define the methods you are mocking:

    class User < ActiveRecord::Base
      # Explicit column definitions for rspec-fire
      def name; super; end
      def email; super; end
    end

### Doubling constants

A particularly excellent feature. You can stub out constants using
`class_double`, removing the need to dependency inject
collaborators (a technique that can sometimes be cumbersome).

    class User
      def suspend!
        EmailNotifier.notify("suspended as")
      end
    end

    describe User, '#suspend!' do
      it 'sends a notification' do
        # Only this one line differs from how you write specs normally
        notifier = class_double("EmailNotifier").as_stubbed_constant

        notifier.should_receive(:notify).with("suspended as")

        user = User.new
        user.suspend!
      end
    end

This will probably become the default behaviour once we figure out a better
name for it.

### Transferring nested constants to doubled constants

When you use `class_double` to replace a class or module
that also acts as a namespace for other classes and constants, your
access to these constants is cut off for the duration of the example
(since the doubled constant does not automatically have all of the
nested constants). The `:transfer_nested_constants` option is provided
to deal with this:

    module MyCoolGem
      class Widget
      end
    end

    # once you do this, you can no longer access MyCoolGem::Widget in your example...
    class_double("MyCoolGem")

    # ...unless you tell rspec-fire to transfer all nested constants
    class_double("MyCoolGem").as_stubbed_constant(:transfer_nested_constants => true)

    # ...or give it a list of constants to transfer
    class_double("MyCoolGem").as_stubbed_constant(:transfer_nested_constants => [:Widget])

### Doubling class methods

Particularly handy for `ActiveRecord` finders. Use `class_double`. If you
dig into the code, you'll find you can create subclasses of `FireDouble` to
check for *any* set of methods.

### Preventing Typo'd Constant Names

`instance_double("MyClas")` will not verify any mocked methods, even when
`MyClass` is loaded, because of the typo in the constant name. There's
an option to help prevent these sorts of fat-finger errors:

    RSpec::Fire.configure do |config|
      config.verify_constant_names = true
    end

When this is set to true, rspec-fire will raise an error when given
the name of an undefined constant. You probably only want to set this
when running your entire test suite, with all production code loaded.
Setting this for an isolated unit test will prevent you from being
able to isolate it!

### Mocking Done Right (tm)

* Only mock methods on collaborators, _not_ the class under test.
* Only mock public methods.

If you can't meet these criteria, your object is probably violating
[SOLID](http://en.wikipedia.org/wiki/SOLID) principles and you should either
refactor or use a non-isolated test.

Compatibility
-------------

Only RSpec 2.11+ is supported. Tested on all the rubies thanks to [Travis
CI][build-link].

[build-link]:  http://travis-ci.org/xaviershay/rspec-fire

Developing
----------

    git clone https://github.com/xaviershay/rspec-fire.git
    bundle install
    bundle exec rake spec

Patches welcome! I won't merge anything that isn't spec'ed, but I can help you
out with that if you are getting stuck.

Still need to support `#stub_chain`.

Status
------

`rspec-fire` is pretty new and not used widely. Yet.
