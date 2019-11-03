<?php

class Utilities {
	private function __construct() { }

	static function get_real_ip_address() {
		return $_SERVER['HTTP_CLIENT_IP'] ?: $_SERVER['HTTP_X_FORWARDED_FOR'] ?: $_SERVER['REMOTE_ADDR'];
	}

	static function generate_salt() {
		return bin2hex(random_bytes(16));
	}

	static function encrypt_password($password) { return password_hash($password, PASSWORD_ARGON2ID); }
	static function var_dump($variable) { ob_end_clean(); echo '<pre>', var_dump($variable); exit; }

	static function slugify($text) {
		$text = preg_replace('~[^\\pL\d]+~u', '-', $text);
		$text = trim($text, '-');
		$text = iconv('utf-8', 'us-ascii//TRANSLIT', $text);
		$text = strtolower($text);
		return preg_replace('~[^-\w]+~', '', $text) ?: 'n-a';
	}

	static function link_to($url) {
		return '/' . $_SESSION['locale'] . '/' . $url;
	}

	static function redirect_to($url) {
		header('Location: ' . Utilities::link_to($url));
		exit;
	}
}