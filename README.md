# revbank - Banking for hackerspace visitors

## Installing RevBank

For new installations, refer to [INSTALLING.md](INSTALLING.md).

## Upgrading RevBank

When upgrading from a previous version, please refer to the file
[UPGRADING.md](UPGRADING.md) because there might be incompatible changes that
require your attention.

## Using RevBank (for end users)

Type `help`.

### Exiting revbank

Exiting is not supported because it's designed to run continuously on its main
terminal. But if you run it from a shell, you can probably stop it using ctrl+Z
and then kill the process (e.g. `kill %1`). RevBank does not keep any files
open, so it's safe to kill when idle.

## Documentation

End-user documentation is provided through the `help` command, which has been
proven to suffice.

For administrators, the **RevBank administrator guide** at
[https://revbank.nl/docs/](https://revbank.nl/docs/) is provided to describe
the inner workings in more detail. The documents are also available in the
source repository as `.md` and `.pod` files. The POD files can be read with
`perldoc` in a terminal.
