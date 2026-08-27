package com.dpt.demo;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

	@Bean
	public PasswordEncoder passwordEncoder() {
		return new BCryptPasswordEncoder();
	}

	@Bean
	public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
		http
			// spring-boot-starter-security tren classpath ma khong co config nao thi
			// mac dinh khoa MOI request sau man hinh login, tra ve 302 redirect. ALB
			// health check cho HTTP 200 nen coi moi instance la unhealthy vinh vien.
			// App nay tu quan ly xac thuc thu cong qua bang Employee (khong dung co
			// che authentication cua Spring Security), nen cho phep moi request.
			.authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
			// login.jsp/register.jsp la form HTML thuan, khong co token CSRF cua
			// Spring Security. Tat CSRF thay vi viet lai toan bo template JSP.
			.csrf(csrf -> csrf.disable());

		return http.build();
	}
}
