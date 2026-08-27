package com.dpt.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;

// App tu quan ly xac thuc thu cong qua bang Employee (xem login.java), khong
// dung UserDetailsService cua Spring Security. Loai tru auto-config nay de
// khoi sinh mot user/password ngau nhien vo dung moi lan khoi dong.
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
public class MyWebAppApplication {

	public static void main(String[] args) {
		SpringApplication.run(MyWebAppApplication.class, args);
	}

}
