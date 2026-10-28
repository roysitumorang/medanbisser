<?php

final class Utilities {
	private function __construct() { }

	static function get_real_ip_address(): string {
		return ($_SERVER['HTTP_CLIENT_IP'] ?? '') ?: ($_SERVER['HTTP_X_FORWARDED_FOR'] ?? '') ?: ($_SERVER['REMOTE_ADDR'] ?? '');
	}

	static function generate_salt(): string {
		return bin2hex(random_bytes(16));
	}

	static function encrypt_password(string $password): string { return password_hash($password, PASSWORD_ARGON2ID); }

	static function var_dump(mixed $variable): never { ob_end_clean(); echo '<pre>'; var_dump($variable); exit; }

	static function slugify(string $text): string {
		$text = preg_replace('~[^\\pL\d]+~u', '-', $text) ?? '';
		$text = trim($text, '-');
		$text = iconv('utf-8', 'us-ascii//TRANSLIT', $text) ?: '';
		$text = strtolower($text);
		return preg_replace('~[^-\w]+~', '', $text) ?: 'n-a';
	}

	/** Zero-pads a member ID to 3 digits (e.g. 7 => "007"). */
	static function pad_id(int|string|null $id): string {
		return str_pad((string) $id, 3, '0', STR_PAD_LEFT);
	}

	static function link_to(string|int $url): string {
		return '/' . ($_SESSION['locale'] ?? '') . '/' . $url;
	}

	static function redirect_to(string|int $url): never {
		header('Location: ' . self::link_to($url));
		exit;
	}
}
