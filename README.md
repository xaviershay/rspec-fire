rspec-fire
==========

Making your test doubles more resilient.

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

Test doubles are sweet for isolating your unit tests, but we lost something in the translation from typed languages. Ruby doesn't have a compiler that can verify the contracts being mocked out are indeed legit. This hurts larger refactorings, since you can totally change a collaborator --- renaming methods, changing the number of arguments --- and all the mocks that were standing in for it will keep pretending everything is ok.

`rspec-fire` mitigates that problem, with very little change to your existing coding style.

One solution would be to disallow stubbing of methods that don't exist. This is what mocha does with its `Mocha::Configuration.prevent(:stubbing_non_existent_method)` option. The downside is, you now have to load the collaborators/dependencies that you are mocking, which kind of defeats the purpose of isolated testing. Not ideal.

Another solution, that `rspec-fire` adopts, is a more relaxed version that only checks that the methods exist _if the doubled class has already been loaded_. No checking will happen when running the spec in isolation, but when run in the context of the full app (either as a full spec run or by explicitly preloading collaborators on the command line) a failure will be triggered if an invalid method is being stubbed.

Usage
-----

Bit of setup in your `spec_helper.rb`:

    require 'rspec/fire'

    RSpec.configure do |config|
      config.include(RSpec::Fire)
    end

Specify the class being doubled in your specs:

    describe User, '#suspend!' do
      it 'sends a notification' do
        # Only this one line differs from how you write specs normally
        notifier = fire_double("EmailNotifier")

        notifier.should_receive(:notify).with("suspended as")

        user = User.new(notifier)
        user.suspend!
      end
    end

Run your specs:

    rspec spec/user_spec.rb                         # Isolated, will pass always
    rspec -Ilib/email_notifier.rb spec/user_spec.rb # Will fail if EmailNotifier#notify method is not defined

Currently only method presence/absense is checked, but theoretically arity can be checked also.

Protips
-------

### Using with an existing Rails project

Create a new file `unit_helper.rb` that _does not_ require `spec_helper.rb`. Require this file where needed for isolated tests. To run an isolated spec in the context of your app:

    rspec -rspec/spec_helper.rb spec/unit/my_spec.rb

### Doubling class methods

Particularly handy for `ActiveRecord` finders. Use `fire_class_double`. If you dig into the code, you'll find you can create subclasses of `FireDouble` to check for *any* set of methods.

### Mocking Done Right (tm)

* Only mock methods on collaborators, _not_ the class under test.
* Only mock public methods.
* Extract common mock setup to keep your specs [DRY](http://en.wikipedia.org/wiki/DRY).

If you can't meet these criteria, your object is probably violating [SOLID](http://en.wikipedia.org/wiki/SOLID) principles and you should either refactor or use a non-isolated test.

Compatibility
-------------

Only RSpec 2 is supported. Tested on Ruby 1.9.2, should work on others though.

Developing
----------

    git clone https://github.com/xaviershay/rspec-fire.git
    bundle install
    bundle exec rake spec

Patches welcome! I won't merge anything that isn't spec'ed, but I can help you out with that if you are getting stuck.

Still need to support `#stub_chain` and `#with` methods.

Status
------

`rspec-fire` is pretty new and not used widely. Yet.
