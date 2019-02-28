## [Unreleased]
### Changed
- Fixed bug in the `Pushdown` store
- `Apecs` module no longer re-exports the entire `Data.Proxy` module, but instead just `Proxy (..)`.
- Added (approximate?) lower and upper version bounds to dependencies

## [0.7.1]
### Added
- `$=` and `$~` operators as synonyms for `set` and `get` respectively
### Removed
- `getAll` and `count`, which were made redundant by `cfold`.

## [0.7.0]
### Added
- The `Reactive` store and module is a redesign of the `Register` store, and provides a more general solution for 'stores that perform additional actions when written to'.
- The `Apecs.Stores.Extra` submodule, which contains the `Pushdown` and `ReadOnly` stores. `Pushdown` adds pushdown semantics to stores, and `ReadOnly` hides the `ExplSet` instances of whatever it wraps.
- The `EntityCounter` and associated functions have all been specified to `IO`, since `Global EntityCounter` only works in IO. Furthermore, `EntityCounter` now uses a `ReadOnly` store, to prevent users from accidentally changing its value.
- `Redirect` component that writes to another entity in `cmap`.
### Changed
- Default stores have `MonadIO m => m` instances, rather than `IO`. This makes it easier to nest `SystemT`.
- All apecs packages have been consolidated into a single git repo.
- `Apecs.Components` contains the components (and corresponding stores) from `Apecs.Core`.

## [0.6.0.0]
### Changed
- Nothing, but since 0.5.1 was API-breaking I've decided to bump to 0.6
## [0.5.1.1]
### Changed
- `Register` needs UndecidableInstances in GHC 8.6.2, I'm looking for a way around this. I've removed it for now.

## [0.5.1.0]
### Added
- The `Register` store, which allows reverse lookups for bounded enums.
  For example, if `Bool` has storage `Register (Map Bool)`, `regLookup True` will yield a list of all entities with a `True` component.
  Can also be used to emulate a hash table, where `fromEnum` is the hashing function.
  This allows us to make simple spatial hashes.
  I'm open to suggestions for better names than Register.
- `cmapIf`, cmap with a conditional test
### Changed
- `ExplInit` now too takes a monad argument.
- Started rewrite of the test suite
- Caches now internally use -2 to denote absence, to avoid possible conflict with -1 as a global entity
### Removed
- The STM instances have been removed, to be moved to their own package

## [0.5.0.0]
### Changed
- `System w a` is now a synonym for `SystemT w IO a`.
  A variable monad argument allows apecs to be run in monads like ST or STM.
  Most of the library has been rewritten to be as permissive as possible in its monad argument.
### Added
- STM stores. These will be moved to a separate package soon.

## [0.4.1.2]
### Changed
- Either can now be deleted, deleting `Either a b` is the same as deleting `(a,b)`.
- Some were missing their inline pragma's, now they don't

## [0.4.1.1]
### Changed
- Export `Get`, `Set`, `Destroy`, `Members` by default
- Export `cfold`, `cfoldM`, `cfoldM_` by default
- Fix () instance

## [0.4.1.0]
### Added
- `cfold`, `cfoldM`, `cfoldM_`
- `Either` instances and `EitherStore`

### Changed
- Changed MaybeStore implementation to no longer use -1 for missing entities.
- Fixed some outdated documentation.
- Change the `global` void entity to -2, just to be sure it won't conflict if accidentally used in a cache.

## [0.4.0.0]
### Added
- A changelog

### Changed
- `Store` is now split into 5 separate type classes; `ExplInit`, `ExplGet`, `ExplSet`, `ExplDestroy`, and `ExplMembers`.
    This makes it illegal to e.g. iterate over a `Not`.
- phantom arguments are now given as `Proxy` values, re-exported from `Data.Proxy`. This makes phantom arguments explicit and avoids undefined values.
