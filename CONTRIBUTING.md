# Contributing

Thanks for contributing. Please keep changes focused and well-tested.

## Development setup

1. Install Salesforce CLI (`sf`)
2. Authenticate to an org:
   ```bash
   sf org login web
   ```
3. Deploy:
   ```bash
   sf project deploy start
   ```
4. Assign permission set:
   ```bash
   sf org assign permset --name Standard_Duplicate_Finder
   ```

## Code style

- Apex: keep methods small, avoid injection risks, and include clear error messages.
- LWC: keep state transitions explicit; prefer small helpers over implicit logic.

## Tests

Run Apex tests:
```bash
sf apex run test --test-level RunLocalTests --result-format human
```

## License

By contributing, you agree that your contributions will be licensed under Apache-2.0.
