package com.shopmini.checkout;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OrderRepository extends JpaRepository<ShopOrder, Long> {
    // the user id is part of the lookup, so one user can never read another user's order
    Optional<ShopOrder> findByIdAndUserId(Long id, String userId);
}
