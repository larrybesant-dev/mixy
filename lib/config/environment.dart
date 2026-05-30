enum Environment { dev, prod }

const String _envName = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

Environment get currentEnv {
  switch (_envName.toLowerCase()) {
    case 'dev':
    case 'development':
      return Environment.dev;
    case 'prod':
    case 'production':
    default:
      return Environment.prod;
  }
}



