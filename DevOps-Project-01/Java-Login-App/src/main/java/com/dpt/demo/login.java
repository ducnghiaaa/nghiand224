package com.dpt.demo;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.ModelAndView;

@Controller
public class login {

	@Autowired
	private DataSource dataSource;

	@Autowired
	private PasswordEncoder passwordEncoder;

	private String userId = "";

	private String errorMessage="";

	@RequestMapping(value = "login", method = RequestMethod.POST)
	public ModelAndView login(String userName, String password) {

		// Chi lay ve ban ghi theo username; khong the so sanh password ngay trong
		// SQL vi cot password luu chuoi bam BCrypt, khong phai plaintext.
		String query = "select username, password from Employee where username = ?";
		try (Connection con = dataSource.getConnection();
				PreparedStatement ps = con.prepareStatement(query)) {
			ps.setString(1, userName);
			try (ResultSet rs = ps.executeQuery()) {
				if (rs.next()) {
					String storedHash = rs.getString("password");
					if (passwordEncoder.matches(password, storedHash)) {
						userId = rs.getString("username");
					}
				}
			}
		} catch (SQLException ex) {
			System.out.println(ex.getMessage());
			errorMessage=ex.getMessage();
		}

		ModelAndView mv;
		if (userId != "")
		{
			mv = new ModelAndView("user");
			mv.addObject("username", userId);
		}
		else
		{

			mv = new ModelAndView("login");
			mv.addObject("errorMessage", errorMessage);
		}

		return mv;
	}



	@RequestMapping(value = "login", method = RequestMethod.GET)
	public ModelAndView registerform()
	{
		ModelAndView mv=new ModelAndView("login");

		return mv;
	}

}
