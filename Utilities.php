<?php

class Utilities {
	private function __construct() { }

	static function get_real_ip_address() {
		$ip = $_SERVER['REMOTE_ADDR'];

		if (!empty($_SERVER['HTTP_CLIENT_IP'])) { $ip = $_SERVER['HTTP_CLIENT_IP']; }
		else if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) { $ip = $_SERVER['HTTP_X_FORWARDED_FOR']; }

		return $ip;
	}

	static function generate_salt() {
		mt_srand(microtime(true) * 100000 + memory_get_usage(true));
		return md5(uniqid(mt_rand(), true));
	}

	static function encrypt_password($password) { return password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]); }
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