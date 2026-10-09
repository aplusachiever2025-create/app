<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
$config = dirname(__DIR__) . '/config.php';
if (!is_file($config)) {
  http_response_code(500);
  echo json_encode(['ok'=>false,'error'=>'Missing server config.php']);
  exit;
}
require_once $config;

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== '' && hash_equals(TM_ALLOWED_ORIGIN, $origin)) {
  header('Access-Control-Allow-Origin: '.$origin);
  header('Vary: Origin');
  header('Access-Control-Allow-Headers: Content-Type, Authorization');
  header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
}
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
  http_response_code(204);
  exit;
}
function reply(int $status, array $data): never {
  http_response_code($status);
  echo json_encode($data, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
  exit;
}
function json_body(): array {
  $v = json_decode(file_get_contents('php://input') ?: '{}', true);
  return is_array($v) ? $v : [];
}
function bearer_token(): string {
  $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
  return preg_match('/^Bearer\\s+(.+)$/i', $h, $m) ? trim($m[1]) : '';
}
try {
  $pdo = new PDO(
    'mysql:host='.TM_DB_HOST.';dbname='.TM_DB_NAME.';charset=utf8mb4',
    TM_DB_USER, TM_DB_PASS,
    [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,
     PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,
     PDO::ATTR_EMULATE_PREPARES=>false]
  );
} catch (Throwable $e) {
  reply(500, ['ok'=>false,'error'=>'Database connection failed; verify test-host configuration.']);
}
$action = (string)($_GET['action'] ?? 'health');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($action === 'health' && $method === 'GET') {
  $tables = (int)$pdo->query('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()')->fetchColumn();
  reply(200, ['ok'=>true,'database'=>'connected','table_count'=>$tables,'auth'=>'native-php-mysql','stage'=>'test-only']);
}
if ($action === 'login' && $method === 'POST') {
  $b = json_body();
  $username = trim((string)($b['username'] ?? ''));
  $password = (string)($b['password'] ?? '');
  if ($username === '' || $password === '') reply(400, ['ok'=>false,'error'=>'Username and password are required']);
  $q = $pdo->prepare('SELECT id,username,display_name,password_hash,active FROM tm_admin_users WHERE username=? LIMIT 1');
  $q->execute([$username]);
  $u = $q->fetch();
  if (!$u || !(int)$u['active'] || !password_verify($password, (string)$u['password_hash'])) {
    reply(401, ['ok'=>false,'error'=>'Invalid credentials']);
  }
  $token = bin2hex(random_bytes(32));
  $hours = max(1, (int)TM_SESSION_TTL_HOURS);
  $expires = (new DateTimeImmutable('now', new DateTimeZone('UTC')))->modify("+{$hours} hours")->format('Y-m-d H:i:s');
  $q = $pdo->prepare('INSERT INTO tm_admin_sessions (admin_user_id,token_hash,expires_at) VALUES (?,?,?)');
  $q->execute([(int)$u['id'], hash('sha256',$token), $expires]);
  $pdo->prepare('UPDATE tm_admin_users SET last_login_at=UTC_TIMESTAMP() WHERE id=?')->execute([(int)$u['id']]);
  reply(200, ['ok'=>true,'token'=>$token,'expires_at'=>$expires,
    'user'=>['id'=>(int)$u['id'],'username'=>$u['username'],'display_name'=>$u['display_name']]]);
}
if (in_array($action, ['me','logout','parents','tutors','cases','dashboard'], true)) {
  $token = bearer_token();
  if ($token === '') reply(401, ['ok'=>false,'error'=>'Missing bearer token']);
  $q = $pdo->prepare('SELECT s.id AS session_id,s.expires_at,u.id,u.username,u.display_name,u.active
    FROM tm_admin_sessions s JOIN tm_admin_users u ON u.id=s.admin_user_id
    WHERE s.token_hash=? LIMIT 1');
  $q->execute([hash('sha256',$token)]);
  $u = $q->fetch();
  if (!$u || !(int)$u['active'] || strtotime($u['expires_at'].' UTC') <= time()) {
    reply(401, ['ok'=>false,'error'=>'Session expired or invalid']);
  }
  if ($action === 'logout' && $method === 'POST') {
    $pdo->prepare('DELETE FROM tm_admin_sessions WHERE id=?')->execute([(int)$u['session_id']]);
    reply(200, ['ok'=>true]);
  }
  if ($action === 'me') reply(200, ['ok'=>true,'user'=>['id'=>(int)$u['id'],'username'=>$u['username'],'display_name'=>$u['display_name']]]);
  reply(501, ['ok'=>false,'error'=>'Business module not migrated yet; do not connect production UI to this endpoint.','module'=>$action]);
}
reply(404, ['ok'=>false,'error'=>'Unknown action']);
